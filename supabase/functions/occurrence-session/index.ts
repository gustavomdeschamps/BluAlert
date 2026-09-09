import { corsHeadersFor } from '../_shared/cors.ts';
import { authenticatedUser, json } from '../_shared/client.ts';

const categories = new Set(['flood', 'landslide', 'tree_or_road', 'structural_risk', 'other']);
const photoTypes = new Set(['image/jpeg', 'image/webp']);

Deno.serve(async (request) => {
  const cors = corsHeadersFor(request);
  if (request.method === 'OPTIONS') return new Response(null, { status: 204, headers: cors });
  try {
    const { client, user } = await authenticatedUser(request);
    const body = await request.json();
    const occurrenceId = String(body.occurrenceId ?? '');
    const idempotencyKey = String(body.idempotencyKey ?? '');
    const description = String(body.description ?? '').trim();
    const media = Array.isArray(body.media) ? body.media : [];
    if (!/^[0-9a-f-]{36}$/i.test(occurrenceId) || !/^[0-9a-f-]{36}$/i.test(idempotencyKey)) throw new Error('INVALID_ID');
    if (!categories.has(body.category) || description.length < 15 || description.length > 600) throw new Error('INVALID_OCCURRENCE');
    if (!Number.isFinite(body.latitude) || !Number.isFinite(body.longitude)) throw new Error('INVALID_LOCATION');
    if (media.length < 1 || media.length > 4 || !media.some((item: any) => item.kind === 'photo')) throw new Error('PHOTO_REQUIRED');

    const { data: config } = await client.from('remote_config').select('*').single();
    if (!config?.uploads_enabled) return json({ error: 'RECEIVING_DISABLED' }, 503, cors);
    const sinceHour = new Date(Date.now() - 3600000).toISOString();
    const sinceDay = new Date(Date.now() - 86400000).toISOString();
    const [{ count: hourCount }, { count: dayCount }] = await Promise.all([
      client.from('occurrences').select('*', { count: 'exact', head: true }).eq('reporter_id', user.id).gte('created_at', sinceHour),
      client.from('occurrences').select('*', { count: 'exact', head: true }).eq('reporter_id', user.id).gte('created_at', sinceDay),
    ]);
    if ((hourCount ?? 0) >= config.hourly_report_limit || (dayCount ?? 0) >= config.daily_report_limit) return json({ error: 'RATE_LIMITED' }, 429, cors);

    const resident = body.resident ?? {};
    const fullName = String(resident.fullName ?? '').trim();
    const phone = String(resident.phone ?? '').replace(/[^+0-9]/g, '');
    if (fullName.length < 3 || !/^\+[1-9][0-9]{9,14}$/.test(phone)) throw new Error('INVALID_PROFILE');
    const { error: profileError } = await client.from('profiles').upsert({
      id: user.id,
      full_name: fullName,
      phone,
      reference_address: String(resident.referenceAddress ?? '').trim() || null,
      reference_latitude: resident.latitude,
      reference_longitude: resident.longitude,
      updated_at: new Date().toISOString(),
    }, { onConflict: 'id' });
    if (profileError) throw profileError;
    const { data: occurrence, error: occurrenceError } = await client.from('occurrences').upsert({
      id: occurrenceId,
      reporter_id: user.id,
      idempotency_key: idempotencyKey,
      category: body.category,
      description,
      latitude: body.latitude,
      longitude: body.longitude,
      accuracy_m: body.accuracyM,
      status: 'uploading',
    }, { onConflict: 'reporter_id,idempotency_key', ignoreDuplicates: true }).select('id,status,received_at,protocol').maybeSingle();
    if (occurrenceError) throw occurrenceError;
    // `ignoreDuplicates` devolve linha vazia quando a ocorrência já existia:
    // nesse caso relemos a linha original em vez de confiar no retorno do upsert.
    let existing = occurrence;
    if (!existing) {
      const { data: prior, error: priorError } = await client
        .from('occurrences')
        .select('id,status,received_at,protocol')
        .eq('reporter_id', user.id)
        .eq('idempotency_key', idempotencyKey)
        .maybeSingle();
      if (priorError) throw priorError;
      if (!prior) throw new Error('OCCURRENCE_NOT_PERSISTED');
      existing = prior;
    }
    // Qualquer estado além de `uploading` significa que a central já registrou
    // o recebimento; reenviar não pode duplicar nem regredir a ocorrência.
    if (existing.status !== 'draft' && existing.status !== 'uploading') {
      return json({ alreadyReceived: true, occurrence: existing }, 200, cors);
    }

    const uploads = [];
    for (const item of media) {
      const kind = item.kind === 'video' ? 'video' : 'photo';
      const byteSize = Number(item.byteSize);
      const mimeType = String(item.mimeType ?? '');
      const maximum = kind === 'photo' ? 800 * 1024 : 10 * 1024 * 1024;
      if ((kind === 'photo' && !photoTypes.has(mimeType)) || (kind === 'video' && mimeType !== 'video/mp4') || byteSize < 1 || byteSize > maximum) throw new Error('INVALID_MEDIA');
      if (kind === 'video' && !config.video_enabled) throw new Error('VIDEO_DISABLED');
      const mediaId = String(item.id ?? '');
      if (!/^[0-9a-f-]{36}$/i.test(mediaId) || !/^[a-f0-9]{64}$/.test(String(item.sha256 ?? ''))) throw new Error('INVALID_MEDIA');
      const extension = mimeType === 'image/webp' ? 'webp' : mimeType === 'video/mp4' ? 'mp4' : 'jpg';
      const objectPath = `${user.id}/${existing.id}/${mediaId}.${extension}`;
      await client.from('occurrence_media').upsert({ id: mediaId, occurrence_id: existing.id, kind, object_path: objectPath, mime_type: mimeType, byte_size: byteSize, sha256: item.sha256 }, { onConflict: 'id' });
      const { data: signed, error: signedError } = await client.storage.from('occurrence-media').createSignedUploadUrl(objectPath, { upsert: true });
      if (signedError) throw signedError;
      uploads.push({ id: mediaId, path: objectPath, signedUrl: signed.signedUrl });
    }
    return json({ occurrenceId: existing.id, uploads }, 201, cors);
  } catch (error) {
    const code = error instanceof Error ? error.message : 'UNKNOWN';
    const status = code === 'UNAUTHORIZED' ? 401 : 400;
    return json({ error: code }, status, cors);
  }
});
