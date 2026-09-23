create or replace function public.change_occurrence_status(
  target_occurrence uuid,
  target_status public.occurrence_status,
  change_reason text default null
) returns public.occurrences
language plpgsql security definer set search_path = '' as $$
declare
  actor_role public.app_role;
  previous public.occurrences;
  changed public.occurrences;
begin
  select role into actor_role from public.profiles where id = auth.uid();
  if auth.uid() is null or actor_role is null or actor_role not in ('operator', 'supervisor') then raise exception 'FORBIDDEN'; end if;
  select * into previous from public.occurrences where id = target_occurrence for update;
  if previous.id is null then raise exception 'NOT_FOUND'; end if;
  if target_status = 'cancelled' and actor_role <> 'supervisor' then raise exception 'SUPERVISOR_REQUIRED'; end if;
  if target_status not in ('opened', 'dispatched', 'resolved', 'cancelled') then raise exception 'INVALID_TRANSITION'; end if;

  update public.occurrences set
    status = target_status,
    opened_at = case when target_status = 'opened' and opened_at is null then now() else opened_at end,
    resolved_at = case when target_status = 'resolved' then now() else resolved_at end,
    updated_at = now()
  where id = target_occurrence returning * into changed;

  insert into public.status_history (occurrence_id, from_status, to_status, author_id, reason)
  values (target_occurrence, previous.status, target_status, auth.uid(), change_reason);
  insert into public.decision_logs (occurrence_id, actor_id, action, previous_value, new_value, justification)
  values (target_occurrence, auth.uid(), 'status_changed', jsonb_build_object('status', previous.status), jsonb_build_object('status', target_status), change_reason);
  return changed;
end;
$$;
create or replace function public.submit_ai_suggestion(
  target_occurrence uuid,
  priority smallint,
  explanation text,
  model_name text,
  model_release text default null
) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  actor_role public.app_role;
  suggestion_id uuid;
begin
  select role into actor_role from public.profiles where id = auth.uid();
  if auth.uid() is null or actor_role is null or actor_role not in ('operator', 'supervisor') then raise exception 'FORBIDDEN'; end if;
  if priority < 1 or priority > 5 then raise exception 'INVALID_PRIORITY'; end if;
  if char_length(trim(explanation)) < 10 then raise exception 'RATIONALE_REQUIRED'; end if;
  if not exists (
    select 1 from public.occurrences
    where id = target_occurrence and status not in ('resolved', 'cancelled')
  ) then raise exception 'OCCURRENCE_NOT_ACTIVE'; end if;

  insert into public.ai_suggestions (
    occurrence_id, suggested_priority, rationale, model, model_version
  ) values (
    target_occurrence, priority, trim(explanation), model_name, model_release
  ) returning id into suggestion_id;

  insert into public.decision_logs (
    occurrence_id, actor_id, action, new_value, justification
  ) values (
    target_occurrence, auth.uid(), 'ai_suggestion_recorded',
    jsonb_build_object('suggestion_id', suggestion_id, 'priority', priority, 'model', model_name),
    'Sugestão automática aguardando avaliação humana'
  );
  return suggestion_id;
end;
$$;
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
  if auth.uid() is null or actor_role is null then raise exception 'FORBIDDEN'; end if;
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
-- Apenas chamadas autenticadas usam estas funções. Os gatilhos e a rotina de
-- escalonamento não são endpoints para moradores ou visitantes.
revoke execute on all functions in schema public from public, anon, authenticated;
grant execute on function public.current_role() to authenticated;
grant execute on function public.change_occurrence_status(uuid, public.occurrence_status, text) to authenticated;
grant execute on function public.submit_ai_suggestion(uuid, smallint, text, text, text) to authenticated;
grant execute on function public.confirm_occurrence_priority(uuid, smallint, text) to authenticated;

-- Somente as leituras e a edição do próprio perfil são feitas diretamente
-- pelo app/painel. Envio de ocorrências usa Edge Functions com validação.
revoke all on all tables in schema public from anon, authenticated;
grant select on public.remote_config to anon, authenticated;
grant select on public.profiles, public.occurrences, public.occurrence_media,
  public.status_history, public.ai_suggestions, public.event_clusters,
  public.event_cluster_occurrences, public.decision_logs, public.operation_queue
  to authenticated;
grant insert, update on public.profiles to authenticated;
grant update on public.remote_config to authenticated;
