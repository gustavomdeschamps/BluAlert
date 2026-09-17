create or replace function public.handle_new_reporter()
returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  supplied_name text := trim(coalesce(new.raw_user_meta_data ->> 'full_name', ''));
  supplied_phone text := regexp_replace(coalesce(new.raw_user_meta_data ->> 'phone', ''), '[^+0-9]', '', 'g');
begin
  -- Contas criadas manualmente para a equipe são promovidas separadamente.
  -- Somente o cadastro completo vindo do app gera um perfil de morador.
  if supplied_name = '' and supplied_phone = '' then return new; end if;
  if supplied_name = '' or supplied_phone !~ '^\+[1-9][0-9]{9,14}$' then
    raise exception 'INVALID_REPORTER_PROFILE';
  end if;
  insert into public.profiles (
    id, full_name, phone, role, reference_address,
    reference_latitude, reference_longitude
  ) values (
    new.id, supplied_name, supplied_phone, 'reporter',
    nullif(trim(coalesce(new.raw_user_meta_data ->> 'reference_address', '')), ''),
    nullif(new.raw_user_meta_data ->> 'reference_latitude', '')::double precision,
    nullif(new.raw_user_meta_data ->> 'reference_longitude', '')::double precision
  ) on conflict (id) do nothing;
  return new;
end;
$$;
