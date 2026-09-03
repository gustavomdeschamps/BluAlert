import { corsHeaders } from '../_shared/cors.ts';
import { adminClient, json } from '../_shared/client.ts';

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  const { data, error } = await adminClient().from('remote_config').select('*').single();
  if (error) return json({ error: 'CONFIG_UNAVAILABLE', pilot_mode: true, human_receiver_confirmed: false, emergency_phone: '199' }, 503);
  return json(data);
});
