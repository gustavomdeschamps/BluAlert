-- Políticas do Storage para o bucket privado `occurrence-media`.
--
-- Até aqui o bucket estava privado e sem nenhuma policy em storage.objects.
-- Consequência: o upload funcionava (URL assinada ignora RLS), mas nenhuma
-- pessoa da operação conseguia abrir a evidência — o painel só teria texto.
--
-- Convenção do caminho, definida em supabase/functions/occurrence-session:
--   <reporter_id>/<occurrence_id>/<media_id>.<ext>
-- O primeiro segmento é sempre o dono da ocorrência, o que permite decidir
-- acesso sem consultar outra tabela.

-- Morador: lê apenas as próprias evidências.
create policy "reporter reads own media"
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'occurrence-media'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- Operação: lê qualquer evidência para poder atender.
create policy "operations read media"
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'occurrence-media'
    and public.current_role() in ('reader', 'operator', 'supervisor')
  );

-- Ninguém escreve por RLS: o envio acontece exclusivamente por URL assinada
-- emitida pela Edge Function, que valida MIME, tamanho e limite de envios.
-- Sem policy de insert/update/delete, qualquer tentativa direta do cliente
-- com a chave anon é recusada.

-- Retenção: a mídia de ocorrências encerradas ganha prazo de expurgo, aplicado
-- pela rotina de limpeza. Sem isso o plano gratuito enche e o piloto para.
create or replace function public.schedule_media_retention()
returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  retention_days integer;
begin
  if new.status in ('resolved', 'cancelled')
     and (old.status is distinct from new.status) then
    select resolved_media_retention_days into retention_days
    from public.remote_config where singleton;
    update public.occurrence_media
      set delete_after = now() + make_interval(days => coalesce(retention_days, 7))
    where occurrence_id = new.id
      and kind <> 'thumbnail'
      and delete_after is null;
  end if;
  return new;
end;
$$;

create trigger occurrence_media_retention
after update of status on public.occurrences
for each row execute function public.schedule_media_retention();
