create extension if not exists pgcrypto;

create type public.app_role as enum ('reporter', 'reader', 'operator', 'supervisor');
create type public.occurrence_status as enum (
  'draft', 'uploading', 'received', 'opened', 'dispatched', 'resolved', 'cancelled'
);
create type public.media_kind as enum ('photo', 'video', 'thumbnail');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null check (char_length(full_name) between 3 and 120),
  phone text not null check (phone ~ '^\+[1-9][0-9]{9,14}$'),
  role public.app_role not null default 'reporter',
  reference_address text,
  reference_latitude double precision,
  reference_longitude double precision,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.occurrences (
  id uuid primary key,
  protocol text unique,
  reporter_id uuid not null references public.profiles(id),
  idempotency_key uuid not null,
  category text not null check (category in (
    'flood', 'landslide', 'tree_or_road', 'structural_risk', 'other'
  )),
  description text not null check (char_length(description) between 15 and 600),
  latitude double precision not null check (latitude between -90 and 90),
  longitude double precision not null check (longitude between -180 and 180),
  accuracy_m double precision check (accuracy_m is null or accuracy_m >= 0),
  status public.occurrence_status not null default 'draft',
  hard_rule_priority smallint not null default 0 check (hard_rule_priority between 0 and 5),
  confirmed_priority smallint check (confirmed_priority between 1 and 5),
  escalation_priority smallint not null default 0 check (escalation_priority between 0 and 5),
  created_at timestamptz not null default now(),
  received_at timestamptz,
  opened_at timestamptz,
  resolved_at timestamptz,
  updated_at timestamptz not null default now(),
  unique (reporter_id, idempotency_key)
);

create table public.occurrence_media (
  id uuid primary key,
  occurrence_id uuid not null references public.occurrences(id) on delete cascade,
  kind public.media_kind not null,
  object_path text not null unique,
  mime_type text not null,
  byte_size bigint not null check (byte_size > 0),
  sha256 text not null check (sha256 ~ '^[a-f0-9]{64}$'),
  upload_confirmed_at timestamptz,
  delete_after timestamptz,
  created_at timestamptz not null default now()
);

create table public.status_history (
  id bigint generated always as identity primary key,
  occurrence_id uuid not null references public.occurrences(id) on delete cascade,
  from_status public.occurrence_status,
  to_status public.occurrence_status not null,
  author_id uuid references public.profiles(id),
  reason text,
  created_at timestamptz not null default now()
);

create table public.ai_suggestions (
  id uuid primary key default gen_random_uuid(),
  occurrence_id uuid not null references public.occurrences(id) on delete cascade,
  suggested_priority smallint not null check (suggested_priority between 1 and 5),
  rationale text not null,
  model text not null,
  model_version text,
  created_at timestamptz not null default now()
);

create table public.decision_logs (
  id bigint generated always as identity primary key,
  occurrence_id uuid not null references public.occurrences(id) on delete cascade,
  actor_id uuid references public.profiles(id),
  action text not null,
  previous_value jsonb,
  new_value jsonb,
  justification text,
  created_at timestamptz not null default now()
);

create table public.event_clusters (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  neighborhood text,
  category text,
  started_at timestamptz not null default now(),
  ended_at timestamptz
);

create table public.event_cluster_occurrences (
  cluster_id uuid references public.event_clusters(id) on delete cascade,
  occurrence_id uuid references public.occurrences(id) on delete cascade,
  primary key (cluster_id, occurrence_id)
);

create table public.remote_config (
  singleton boolean primary key default true check (singleton),
  pilot_mode boolean not null default true,
  human_receiver_confirmed boolean not null default false,
  emergency_phone text not null default '199',
  uploads_enabled boolean not null default true,
  video_enabled boolean not null default true,
  resolved_media_retention_days integer not null default 7 check (resolved_media_retention_days between 1 and 30),
  thumbnail_retention_days integer not null default 90 check (thumbnail_retention_days between 7 and 365),
  hourly_report_limit integer not null default 5 check (hourly_report_limit between 1 and 20),
  daily_report_limit integer not null default 20 check (daily_report_limit between 1 and 100),
  updated_at timestamptz not null default now(),
  updated_by uuid references public.profiles(id)
);

insert into public.remote_config (singleton) values (true);

create index occurrences_queue_idx on public.occurrences
  (status, hard_rule_priority desc, escalation_priority desc, created_at asc);
create index occurrences_updated_idx on public.occurrences (updated_at);
create index media_retention_idx on public.occurrence_media (delete_after)
  where delete_after is not null;
create index history_occurrence_idx on public.status_history (occurrence_id, created_at desc);

alter table public.profiles enable row level security;
alter table public.occurrences enable row level security;
alter table public.occurrence_media enable row level security;
alter table public.status_history enable row level security;
alter table public.ai_suggestions enable row level security;
alter table public.decision_logs enable row level security;
alter table public.event_clusters enable row level security;
alter table public.event_cluster_occurrences enable row level security;
alter table public.remote_config enable row level security;

create function public.current_role() returns public.app_role
language sql stable security definer set search_path = '' as $$
  select coalesce((select role from public.profiles where id = auth.uid()), 'reporter');
$$;

create policy "profile reads self" on public.profiles for select
  using (id = auth.uid() or public.current_role() in ('reader', 'operator', 'supervisor'));
create policy "profile updates self" on public.profiles for update
  using (id = auth.uid()) with check (id = auth.uid() and role = 'reporter');
create policy "reporter reads own occurrences" on public.occurrences for select
  using (reporter_id = auth.uid() or public.current_role() in ('reader', 'operator', 'supervisor'));
create policy "operations reads media metadata" on public.occurrence_media for select
  using (public.current_role() in ('reader', 'operator', 'supervisor'));
create policy "operations reads history" on public.status_history for select
  using (public.current_role() in ('reader', 'operator', 'supervisor'));
create policy "operations reads suggestions" on public.ai_suggestions for select
  using (public.current_role() in ('reader', 'operator', 'supervisor'));
create policy "supervisor reads decisions" on public.decision_logs for select
  using (public.current_role() = 'supervisor');
create policy "operations reads clusters" on public.event_clusters for select
  using (public.current_role() in ('reader', 'operator', 'supervisor'));
create policy "operations reads cluster links" on public.event_cluster_occurrences for select
  using (public.current_role() in ('reader', 'operator', 'supervisor'));
create policy "everyone reads pilot config" on public.remote_config for select using (true);

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'occurrence-media', 'occurrence-media', false, 10485760,
  array['image/jpeg', 'image/webp', 'video/mp4']
)
on conflict (id) do update set
  public = false,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

alter publication supabase_realtime add table public.occurrences;
