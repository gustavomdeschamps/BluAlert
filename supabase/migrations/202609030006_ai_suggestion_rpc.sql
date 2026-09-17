create function public.submit_ai_suggestion(
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
  if actor_role not in ('operator', 'supervisor') then raise exception 'FORBIDDEN'; end if;
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

grant execute on function public.submit_ai_suggestion(uuid, smallint, text, text, text)
to authenticated;
