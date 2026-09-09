import { corsHeadersFor } from '../_shared/cors.ts';
import { authenticatedUser, json } from '../_shared/client.ts';

Deno.serve(async (request) => {
  const cors = corsHeadersFor(request);
  if (request.method === 'OPTIONS') return new Response(null, { status: 204, headers: cors });
  try {
    const { client, user } = await authenticatedUser(request);
    const { occurrenceId } = await request.json();
    if (!/^[0-9a-f-]{36}$/i.test(String(occurrenceId ?? ''))) throw new Error('INVALID_ID');
    // `maybeSingle` para que uma ocorrência inexistente vire NOT_FOUND explícito
    // em vez de estourar acesso a nulo e virar um genérico "UNKNOWN".
    const { data: occurrence, error: lookupError } = await client
      .from('occurrences')
      .select('id,status,protocol,received_at')
      .eq('id', occurrenceId)
      .eq('reporter_id', user.id)
      .maybeSingle();
    if (lookupError) throw lookupError;
    if (!occurrence) return json({ error: 'NOT_FOUND' }, 404, cors);
    // Já confirmada anteriormente: devolve o mesmo protocolo, sem reprocessar.
    if (occurrence.status !== 'draft' && occurrence.status !== 'uploading') {
      return json({ id: occurrence.protocol, receivedAt: occurrence.received_at }, 200, cors);
    }
    const { data: media } = await client.from('occurrence_media').select('*').eq('occurrence_id', occurrence.id);
    if (!media?.some((item) => item.kind === 'photo')) return json({ error: 'PHOTO_REQUIRED' }, 409, cors);
    for (const item of media) {
      const { data: objects } = await client.storage.from('occurrence-media').list(item.object_path.substring(0, item.object_path.lastIndexOf('/')), { search: item.object_path.split('/').pop() });
      const object = objects?.find((entry) => item.object_path.endsWith(`/${entry.name}`));
      if (!object || Number(object.metadata?.size) !== Number(item.byte_size)) return json({ error: 'UPLOAD_INCOMPLETE' }, 409, cors);
    }
    const receivedAt = new Date().toISOString();
    const protocol = `BLU-${receivedAt.slice(0, 10).replaceAll('-', '')}-${occurrence.id.replaceAll('-', '').slice(0, 8).toUpperCase()}`;
    // A transição só vale se a linha ainda estava aguardando confirmação. Sem o
    // `select`, uma corrida (dois confirms simultâneos) atualizaria zero linhas
    // e mesmo assim devolveríamos 201 com um protocolo que nunca foi gravado —
    // o app mostraria "recebido" para algo que a central não registrou.
    const { data: confirmed, error } = await client
      .from('occurrences')
      .update({ status: 'received', protocol, received_at: receivedAt, updated_at: receivedAt })
      .eq('id', occurrence.id)
      .in('status', ['draft', 'uploading'])
      .select('protocol,received_at')
      .maybeSingle();
    if (error) throw error;
    if (!confirmed) {
      // Outra chamada confirmou primeiro: devolvemos o protocolo real gravado.
      const { data: settled } = await client
        .from('occurrences')
        .select('protocol,received_at')
        .eq('id', occurrence.id)
        .maybeSingle();
      if (!settled?.protocol) return json({ error: 'NOT_CONFIRMED' }, 409, cors);
      return json({ id: settled.protocol, receivedAt: settled.received_at }, 200, cors);
    }
    await client.from('occurrence_media').update({ upload_confirmed_at: receivedAt }).eq('occurrence_id', occurrence.id);
    await client.from('status_history').insert({ occurrence_id: occurrence.id, from_status: occurrence.status, to_status: 'received', author_id: user.id, reason: 'Upload confirmado pelo servidor' });
    return json({ id: confirmed.protocol, receivedAt: confirmed.received_at }, 201, cors);
  } catch (error) {
    const code = error instanceof Error ? error.message : 'UNKNOWN';
    return json({ error: code }, code === 'UNAUTHORIZED' ? 401 : 400, cors);
  }
});
