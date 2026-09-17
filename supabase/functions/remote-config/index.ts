import { corsHeadersFor } from '../_shared/cors.ts';
import { adminClient, json } from '../_shared/client.ts';

Deno.serve(async (request) => {
  const cors = corsHeadersFor(request);
  if (request.method === 'OPTIONS') return new Response(null, { status: 204, headers: cors });
  const { data, error } = await adminClient().from('remote_config').select('*').single();
  // Indisponibilidade cai para o lado seguro: modo piloto ligado, central humana
  // não confirmada e o 199 sempre visível.
  if (error) return json({ error: 'CONFIG_UNAVAILABLE', pilot_mode: true, human_receiver_confirmed: false, emergency_phone: '199' }, 503, cors);
  return json(data, 200, cors);
});
