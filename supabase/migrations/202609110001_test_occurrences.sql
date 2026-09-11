-- Preserve the provenance of coordinates and keep demonstrations visibly
-- separated from real emergency reports.
alter table public.occurrences
  add column if not exists location_source text not null default 'gps'
    check (location_source in ('gps', 'manually_adjusted', 'test_address')),
  add column if not exists is_test boolean not null default false;

create index if not exists occurrences_is_test_idx
  on public.occurrences (is_test, created_at desc);
