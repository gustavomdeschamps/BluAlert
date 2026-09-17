create function public.detect_hard_rule_priority(category text, description text)
returns smallint
language sql immutable set search_path = '' as $$
  select case
    when description ~* '(soterrad|desabamento.{0,40}pessoa|sem respirar|inconsciente|risco de vida)' then 5
    when description ~* '(ilhada|pres[oa].{0,30}(água|enchente)|crian[çc]a|beb[eê]|idos[oa]|cadeirante|ferid[oa])' then 4
    when category in ('landslide', 'structural_risk') and description ~* '(pessoa|casa|morador|família)' then 4
    when description ~* '(água subindo|rachadura aumentando|poste caindo|fio elétrico|vazamento de gás)' then 3
    else 0
  end::smallint;
$$;

create function public.apply_hard_triage_rules()
returns trigger language plpgsql set search_path = '' as $$
begin
  new.hard_rule_priority := public.detect_hard_rule_priority(new.category, new.description);
  return new;
end;
$$;

create trigger occurrence_hard_triage
before insert or update of category, description on public.occurrences
for each row execute function public.apply_hard_triage_rules();

create function public.refresh_occurrence_escalation()
returns integer
language plpgsql security definer set search_path = '' as $$
declare affected integer;
begin
  update public.occurrences
  set escalation_priority = case
        when now() - created_at >= interval '60 minutes' then 5
        when now() - created_at >= interval '30 minutes' then 4
        when now() - created_at >= interval '15 minutes' then 3
        when now() - created_at >= interval '5 minutes' then 2
        else 1
      end,
      updated_at = now()
  where status = 'received' and opened_at is null;
  get diagnostics affected = row_count;
  return affected;
end;
$$;

create view public.operation_queue
with (security_invoker = true) as
select
  o.*,
  greatest(
    o.hard_rule_priority,
    o.escalation_priority,
    coalesce(o.confirmed_priority, 0),
    coalesce(ai.suggested_priority, 0)
  ) as effective_priority,
  case
    when o.hard_rule_priority >= greatest(o.escalation_priority, coalesce(o.confirmed_priority, 0), coalesce(ai.suggested_priority, 0))
      and o.hard_rule_priority > 0 then 'Regra de risco à vida'
    when o.escalation_priority >= greatest(coalesce(o.confirmed_priority, 0), coalesce(ai.suggested_priority, 0))
      and o.escalation_priority > 1 then 'Tempo sem abertura'
    when o.confirmed_priority is not null then 'Prioridade confirmada por operador'
    when ai.suggested_priority is not null then 'Sugestão de triagem assistida'
    else 'Ordem de chegada'
  end as ordering_reason,
  ai.rationale as ai_rationale
from public.occurrences o
left join lateral (
  select suggested_priority, rationale
  from public.ai_suggestions s
  where s.occurrence_id = o.id
  order by s.created_at desc
  limit 1
) ai on true
where o.status not in ('resolved', 'cancelled');

grant select on public.operation_queue to authenticated;

create function public.change_occurrence_status(
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
  if actor_role not in ('operator', 'supervisor') then raise exception 'FORBIDDEN'; end if;
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

revoke all on function public.refresh_occurrence_escalation() from public, anon, authenticated;
grant execute on function public.change_occurrence_status(uuid, public.occurrence_status, text) to authenticated;

create policy "supervisor updates pilot config" on public.remote_config for update
  using (public.current_role() = 'supervisor')
  with check (public.current_role() = 'supervisor');
