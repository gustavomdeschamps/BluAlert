create policy "reporter creates own profile" on public.profiles for insert
  with check (id = auth.uid() and role = 'reporter');
