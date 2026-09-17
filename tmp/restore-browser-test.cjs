(async () => {
  const targets = await (await fetch('http://127.0.0.1:57680/json/list')).json();
  const app = targets.find(target => target.type === 'page' && target.url.startsWith('http://localhost:57653/'));
  if (!app) throw new Error('Janela de teste nao encontrada');
  const socket = new WebSocket(app.webSocketDebuggerUrl);
  await new Promise((resolve,reject) => { socket.addEventListener('open',resolve,{once:true}); socket.addEventListener('error',reject,{once:true}); });
  let id = 0;
  for (const method of ['Emulation.clearGeolocationOverride','Emulation.clearDeviceMetricsOverride']) {
    const messageId = ++id;
    const done = new Promise((resolve,reject) => {
      const listener = event => {
        const response = JSON.parse(String(event.data));
        if (response.id === messageId) {socket.removeEventListener('message',listener); if(response.error)reject(new Error('Falha ao restaurar simulacao'));else resolve();}
      };
      socket.addEventListener('message',listener);
    });
    socket.send(JSON.stringify({id:messageId,method,params:{}}));
    await done;
  }
  socket.close();
  console.log('Localizacao simulada e tamanho de teste removidos. Nenhuma sessao de autenticacao foi lida ou alterada.');
})().catch(error => {console.error(error.message);process.exitCode=1;});
