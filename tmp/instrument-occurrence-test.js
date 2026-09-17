(() => {
  window.__blualertTestResults = [];
  const originalFetch = window.fetch;
  const originalOpen = XMLHttpRequest.prototype.open;
  const originalSend = XMLHttpRequest.prototype.send;
  const transform = body => {
    try {
      const data = JSON.parse(body);
      if (String(data.description).startsWith('TESTE ESCOLAR BLUALERT: verificacao de envio')) {
        data.isTest = true;
        data.locationSource = 'testAddress';
        return JSON.stringify(data);
      }
    } catch {}
    return body;
  };
  window.fetch = async function(input, options) {
    const url = typeof input === 'string' ? input : input.url;
    if (String(url).includes('/functions/v1/occurrence-session') && options?.body) {
      options = {...options, body:transform(options.body)};
    }
    const response = await originalFetch.call(this, input, options);
    if (/\/functions\/v1\/occurrence-(session|confirm)/.test(String(url))) {
      let body;
      try { body = await response.clone().json(); } catch {}
      window.__blualertTestResults.push({url:String(url).split('/').pop(), status:response.status, error:body?.error, occurrenceId:body?.occurrenceId, protocol:body?.id});
    }
    return response;
  };
  XMLHttpRequest.prototype.open = function(method, url, ...rest) {
    this.__testUrl = String(url);
    return originalOpen.call(this, method, url, ...rest);
  };
  XMLHttpRequest.prototype.send = function(body) {
    if (this.__testUrl?.includes('/functions/v1/occurrence-session')) body = transform(body);
    if (/\/functions\/v1\/occurrence-(session|confirm)/.test(this.__testUrl || '')) {
      this.addEventListener('load', () => {
        let response;
        try { response = typeof this.response === 'object' ? this.response : JSON.parse(this.responseText); } catch {}
        window.__blualertTestResults.push({url:this.__testUrl.split('/').pop(), status:this.status, error:response?.error, occurrenceId:response?.occurrenceId, protocol:response?.id});
      }, {once:true});
    }
    return originalSend.call(this, body);
  };
  window.__restoreBlualertTest = () => {
    window.fetch = originalFetch;
    XMLHttpRequest.prototype.open = originalOpen;
    XMLHttpRequest.prototype.send = originalSend;
  };
  return 'Teste identificado: somente este relato sera marcado is_test=true.';
})()
