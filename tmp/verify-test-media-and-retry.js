(async () => {
  const storageKey = Object.keys(localStorage).find(key => key.endsWith('blualert_backend_session_v1'));
  let session = JSON.parse(localStorage.getItem(storageKey));
  if (typeof session === 'string') session = JSON.parse(session);
  const base = 'https://mnpdgswaujmryhykyyaf.supabase.co';
  const headers = {apikey:'sb_publishable_Qm0xBVagBhbbAomg-RV79w_HRXec_VM', Authorization:`Bearer ${session.accessToken}`, 'Content-Type':'application/json'};
  const id = '1cdc65fa-56b9-4c1e-9088-607142245e1d';
  const mediaResponse = await fetch(`${base}/rest/v1/occurrence_media?occurrence_id=eq.${id}&select=id,kind,object_path,mime_type,byte_size,sha256,upload_confirmed_at`, {headers});
  const media = await mediaResponse.json();
  if (!Array.isArray(media) || !media.length) return {error:'NO_MEDIA',status:mediaResponse.status};
  const photo = media.find(item => item.kind === 'photo');
  const signedResponse = await fetch(`${base}/storage/v1/object/sign/occurrence-media/${photo.object_path}`, {method:'POST',headers,body:JSON.stringify({expiresIn:60})});
  const signed = await signedResponse.json();
  let integrity = false;
  let photoBytes = null;
  if (signed.signedURL || signed.signedUrl) {
    const address = signed.signedURL || signed.signedUrl;
    const photoResponse = await fetch(address.startsWith('http') ? address : `${base}/storage/v1${address}`);
    const bytes = await photoResponse.arrayBuffer();
    photoBytes = bytes.byteLength;
    const digest = await crypto.subtle.digest('SHA-256', bytes);
    const hash = Array.from(new Uint8Array(digest), byte => byte.toString(16).padStart(2,'0')).join('');
    integrity = photoResponse.ok && hash === photo.sha256 && photoBytes === photo.byte_size;
  }
  const retryResponse = await fetch(`${base}/functions/v1/occurrence-session`, {method:'POST',headers,body:JSON.stringify({
    occurrenceId:id,idempotencyKey:id,category:'flood',
    description:'TESTE ESCOLAR BLUALERT: verificacao de envio e recebimento no painel. Imagem de exemplo; nao e uma emergencia real e nao solicita atendimento.',
    latitude:-26.907254713,longitude:-49.07648278,accuracyM:null,locationSource:'testAddress',isTest:true,
    media:media.map(item=>({id:item.id,kind:item.kind,mimeType:item.mime_type,byteSize:item.byte_size,sha256:item.sha256}))
  })});
  const retry = await retryResponse.json();
  const result = {mediaMetadataStatus:mediaResponse.status,photoConfirmed:!!photo.upload_confirmed_at,signedPhotoStatus:signedResponse.status,photoBytes,photoIntegrityMatches:integrity,retryStatus:retryResponse.status,retryAlreadyReceived:retry.alreadyReceived===true,retryProtocol:retry.occurrence?.protocol};
  window.__blualertMediaVerification = result;
  window.__restoreBlualertTest?.();
  return result;
})()
