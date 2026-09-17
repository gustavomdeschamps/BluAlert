(async () => {
  const storageKey = Object.keys(localStorage).find(key => key.endsWith('blualert_backend_session_v1'));
  if (!storageKey) return {error:'SESSION_STORAGE_NOT_FOUND'};
  let session = JSON.parse(localStorage.getItem(storageKey));
  if (typeof session === 'string') session = JSON.parse(session);
  const base = 'https://mnpdgswaujmryhykyyaf.supabase.co';
  const headers = {apikey:'sb_publishable_Qm0xBVagBhbbAomg-RV79w_HRXec_VM', Authorization:`Bearer ${session.accessToken}`};
  const response = await fetch(`${base}/rest/v1/operation_queue?id=eq.1cdc65fa-56b9-4c1e-9088-607142245e1d&select=id,protocol,status,is_test,description,effective_priority`, {headers});
  const records = await response.json();
  window.__blualertQueueVerification = {status:response.status, records};
  return window.__blualertQueueVerification;
})()
