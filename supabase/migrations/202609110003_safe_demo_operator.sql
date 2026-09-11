-- The resident can inspect media metadata only for their own report. Storage
-- already has the equivalent owner-only policy for the binary object.
create policy "reporter reads own media metadata"
on public.occurrence_media for select
to authenticated
using (
  exists (
    select 1 from public.occurrences o
    where o.id = occurrence_id and o.reporter_id = auth.uid()
  )
);

-- Operational roles keep full authority. A reporter may classify only their
-- own explicitly marked test report, which supports classroom demonstrations
-- without granting access to real reports or other residents.
create or replace function public.confirm_occurrence_priority(
  target_occurrence uuid,
  target_priority smallint,
  justification text
) returns public.occurrences
language plpgsql security definer set search_path = '' as $$
declare
  actor_role public.app_role;
  previous public.occurrences;
  changed public.occurrences;
begin
  select role into actor_role from public.profiles where id = auth.uid();
  select * into previous from public.occurrences where id = target_occurrence for update;
  if previous.id is null then raise exception 'NOT_FOUND'; end if;
  if actor_role not in ('operator', 'supervisor')
     and not (actor_role = 'reporter' and previous.is_test and previous.reporter_id = auth.uid()) then
    raise exception 'FORBIDDEN';
  end if;
  if target_priority < 1 or target_priority > 5 then raise exception 'INVALID_PRIORITY'; end if;
  if char_length(trim(justification)) < 5 then raise exception 'JUSTIFICATION_REQUIRED'; end if;

  update public.occurrences
  set confirmed_priority = target_priority, updated_at = now()
  where id = target_occurrence returning * into changed;

  insert into public.decision_logs
    (occurrence_id, actor_id, action, previous_value, new_value, justification)
  values
    (target_occurrence, auth.uid(), 'priority_confirmed_demo',
     jsonb_build_object('priority', previous.confirmed_priority),
     jsonb_build_object('priority', target_priority), trim(justification));
  return changed;
end;
$$;
