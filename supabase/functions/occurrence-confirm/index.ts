import { corsHeaders } from '../_shared/cors.ts';
import { authenticatedUser, json } from '../_shared/client.ts';

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  try {
    const { client, user } = await authenticatedUser(request);
    const { occurrenceId } = await request.json();
    const { data: occurrence } = await client.from('occurrences').select('id,status,protocol,received_at').eq('id', occurrenceId).eq('reporter_id', user.id).single();
    if (occurrence.status === 'received') return json({ id: occurrence.protocol, receivedAt: occurrence.received_at });
    const { data: media } = await client.from('occurrence_media').select('*').eq('occurrence_id', occurrence.id);
    if (!media?.some((item) => item.kind === 'photo')) return json({ error: 'PHOTO_REQUIRED' }, 409);
    for (const item of media) {
      const { data: objects } = await client.storage.from('occurrence-media').list(item.object_path.substring(0, item.object_path.lastIndexOf('/')), { search: item.object_path.split('/').pop() });
      const object = objects?.find((entry) => item.object_path.endsWith(`/${entry.name}`));
      if (!object || Number(object.metadata?.size) !== Number(item.byte_size)) return json({ error: 'UPLOAD_INCOMPLETE' }, 409);
    }
    const receivedAt = new Date().toISOString();
    const protocol = `BLU-${receivedAt.slice(0, 10).replaceAll('-', '')}-${occurrence.id.slice(0, 6).toUpperCase()}`;
    const { error } = await client.from('occurrences').update({ status: 'received', protocol, received_at: receivedAt, updated_at: receivedAt }).eq('id', occurrence.id).eq('status', 'uploading');
    if (error) throw error;
    await client.from('occurrence_media').update({ upload_confirmed_at: receivedAt }).eq('occurrence_id', occurrence.id);
    await client.from('status_history').insert({ occurrence_id: occurrence.id, from_status: 'uploading', to_status: 'received', author_id: user.id, reason: 'Upload confirmado pelo servidor' });
    return json({ id: protocol, receivedAt }, 201);
  } catch (error) {
    const code = error instanceof Error ? error.message : 'UNKNOWN';
    return json({ error: code }, code === 'UNAUTHORIZED' ? 401 : 400);
  }
});
