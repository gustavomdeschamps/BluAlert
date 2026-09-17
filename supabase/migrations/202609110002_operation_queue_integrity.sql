-- Only confirmed reports belong in the operations room. Draft/uploading rows
-- may exist while the app retries, but showing them creates a false receipt.
drop view if exists public.operation_queue;

create view public.operation_queue
with (security_invoker = true) as
select
  o.*,
  greatest(
    o.hard_rule_priority,
    o.escalation_priority,
    coalesce(o.confirmed_priority, 0)
  ) as effective_priority,
  case
    when o.hard_rule_priority >= greatest(o.escalation_priority, coalesce(o.confirmed_priority, 0))
      and o.hard_rule_priority > 0 then 'Regra de risco à vida'
    when o.escalation_priority >= coalesce(o.confirmed_priority, 0)
      and o.escalation_priority > 1 then 'Tempo sem abertura'
    when o.confirmed_priority is not null then 'Prioridade confirmada por operador'
    when ai.suggested_priority is not null then 'Sugestão da IA aguardando confirmação'
    else 'Ordem de chegada'
  end as ordering_reason,
  ai.rationale as ai_rationale,
  ai.suggested_priority as ai_suggested_priority
from public.occurrences o
left join lateral (
  select suggested_priority, rationale
  from public.ai_suggestions s
  where s.occurrence_id = o.id
  order by s.created_at desc
  limit 1
) ai on true
where o.status in ('received', 'opened', 'dispatched');

grant select on public.operation_queue to authenticated;

-- Clear only demonstration records. Metadata remains auditable and media is
-- scheduled by the existing retention trigger instead of being hard-deleted.
update public.occurrences
set status = 'resolved', resolved_at = now(), updated_at = now()
where is_test and status not in ('resolved', 'cancelled');

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
  if actor_role not in ('operator', 'supervisor') then raise exception 'FORBIDDEN'; end if;
  if target_priority < 1 or target_priority > 5 then raise exception 'INVALID_PRIORITY'; end if;
  if char_length(trim(justification)) < 5 then raise exception 'JUSTIFICATION_REQUIRED'; end if;

  select * into previous from public.occurrences where id = target_occurrence for update;
  if previous.id is null then raise exception 'NOT_FOUND'; end if;

  update public.occurrences
  set confirmed_priority = target_priority, updated_at = now()
  where id = target_occurrence returning * into changed;

  insert into public.decision_logs
    (occurrence_id, actor_id, action, previous_value, new_value, justification)
  values
    (target_occurrence, auth.uid(), 'priority_confirmed',
     jsonb_build_object('priority', previous.confirmed_priority),
     jsonb_build_object('priority', target_priority), trim(justification));
  return changed;
end;
$$;

grant execute on function public.confirm_occurrence_priority(uuid, smallint, text)
to authenticated;
