-- Conferência somente de leitura antes da migração do Supabase.
-- Não retorna e-mails, nomes, endereços, hashes ou caminhos dos arquivos.

select
  (select count(*) from auth.users) as users,
  (select count(*) from public.profiles) as profiles,
  (select count(*) from public.occurrences) as occurrences,
  (select count(*) from public.occurrence_media) as media_records,
  (select count(*) from storage.objects where bucket_id = 'occurrence-media') as media_objects,
  (select count(*) from public.status_history) as history_records;

select 'users_without_profile' as check_name, count(*) as affected
from auth.users u left join public.profiles p on p.id = u.id where p.id is null
union all
select 'profiles_without_user', count(*)
from public.profiles p left join auth.users u on u.id = p.id where u.id is null
union all
select 'occurrences_without_profile', count(*)
from public.occurrences c left join public.profiles p on p.id = c.reporter_id where p.id is null
union all
select 'media_without_object', count(*)
from public.occurrence_media m
left join storage.objects o on o.bucket_id = 'occurrence-media' and o.name = m.object_path
where o.id is null
union all
select 'objects_without_media', count(*)
from storage.objects o
left join public.occurrence_media m on m.object_path = o.name
where o.bucket_id = 'occurrence-media' and m.id is null;

select role::text as role, count(*) as total from public.profiles group by role;
select status::text as status, is_test, count(*) as total
from public.occurrences group by status, is_test;

-- Apenas o prefixo identifica a família do algoritmo; nunca exportar o hash
-- para um relatório ou log. A transferência real exige canal privado.
select left(encrypted_password, 4) as hash_family, count(*) as total
from auth.users group by left(encrypted_password, 4);
