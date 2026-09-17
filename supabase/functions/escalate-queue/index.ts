import { adminClient, json } from '../_shared/client.ts';

Deno.serve(async (request) => {
  const expected = Deno.env.get('CRON_SECRET');
  if (!expected || request.headers.get('x-cron-secret') !== expected) return json({ error: 'UNAUTHORIZED' }, 401);
  const { data, error } = await adminClient().rpc('refresh_occurrence_escalation');
  if (error) return json({ error: 'ESCALATION_FAILED' }, 500);
  return json({ updated: data });
});
