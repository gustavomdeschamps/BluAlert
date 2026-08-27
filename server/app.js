const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');

const port = Number(process.env.PORT || 3000);
const webRoot = path.resolve(__dirname, '..', 'build', 'web');
const sourceUrl = 'https://defesacivil.blumenau.sc.gov.br/c/meteorologia/aplicativo';
const occurrenceRoot = path.resolve(__dirname, 'data', 'occurrences');

const mimeTypes = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.png': 'image/png',
  '.otf': 'font/otf',
  '.wasm': 'application/wasm',
};

function stripHtml(html) {
  return html
    .replace(/<script[\s\S]*?<\/script>/gi, ' ')
    .replace(/<style[\s\S]*?<\/style>/gi, ' ')
    .replace(/<[^>]+>/g, ' ')
    .replaceAll('&ccedil;', 'ç')
    .replaceAll('&atilde;', 'ã')
    .replaceAll('&aacute;', 'á')
    .replaceAll('&iacute;', 'í')
    .replaceAll('&uacute;', 'ú')
    .replaceAll('&nbsp;', ' ')
    .replace(/\s+/g, ' ');
}

function parseSituation(html) {
  const text = stripHtml(html);
  const level = text.match(/N[ií]vel do Rio\s*\|?\s*([0-9]+[,.][0-9]+\s*m)/i);
  const status = text.match(/Itaja[ií]-A[çc]u\s*\|?\s*(Normalidade|Observa[çc][aã]o|Aten[çc][aã]o|Alerta M[aá]ximo|Alerta)/i);
  const publication = text.match(/Situa[çc][aã]o publicada em\s*([0-9]{2}\/[0-9]{2}\/[0-9]{4})/i);
  if (!level || !status) throw new Error('Situação atual não localizada na página oficial.');
  return {
    riverLevel: level[1].replaceAll(' ', ''),
    riverStatus: status[1],
    publishedAt: publication?.[1] || 'horário informado na fonte',
    source: sourceUrl,
  };
}

async function serveSituation(response) {
  try {
    const official = await fetch(sourceUrl, {
      headers: { Accept: 'text/html', 'User-Agent': 'BluAlert/1.0 Blumenau' },
      signal: AbortSignal.timeout(12000),
    });
    if (!official.ok) throw new Error(`AlertaBlu respondeu ${official.status}.`);
    const situation = parseSituation(await official.text());
    response.writeHead(200, {
      'Content-Type': 'application/json; charset=utf-8',
      'Cache-Control': 'no-store',
    });
    response.end(JSON.stringify(situation));
  } catch (error) {
    response.writeHead(502, {
      'Content-Type': 'application/json; charset=utf-8',
      'Cache-Control': 'no-store',
    });
    response.end(JSON.stringify({
      error: 'Fonte oficial temporariamente indisponível.',
      detail: error.message,
      source: sourceUrl,
    }));
  }
}

function readJsonBody(request, limit = 28 * 1024 * 1024) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    let size = 0;
    request.on('data', (chunk) => {
      size += chunk.length;
      if (size > limit) {
        reject(new Error('O envio ultrapassa o limite de 28 MB.'));
        request.destroy();
        return;
      }
      chunks.push(chunk);
    });
    request.on('end', () => {
      try {
        resolve(JSON.parse(Buffer.concat(chunks).toString('utf8')));
      } catch (_) {
        reject(new Error('Conteúdo do envio inválido.'));
      }
    });
    request.on('error', reject);
  });
}

function safeExtension(mimeType) {
  const extensions = {
    'image/jpeg': '.jpg',
    'image/png': '.png',
    'image/webp': '.webp',
    'video/mp4': '.mp4',
    'video/webm': '.webm',
    'video/quicktime': '.mov',
  };
  return extensions[mimeType] || '.bin';
}

async function receiveOccurrence(request, response) {
  try {
    const payload = await readJsonBody(request);
    const resident = payload?.resident;
    const location = payload?.location;
    const attachments = payload?.attachments;
    if (!resident?.fullName || !resident?.phone ||
        !payload?.category || String(payload?.description || '').trim().length < 15 ||
        !Number.isFinite(location?.latitude) || !Number.isFinite(location?.longitude) ||
        !Array.isArray(attachments) || attachments.length === 0) {
      throw new Error('Preencha identificação, descrição, localização e evidências.');
    }

    const id = `BLU-${new Date().toISOString().slice(0, 10).replaceAll('-', '')}-${crypto.randomBytes(3).toString('hex').toUpperCase()}`;
    const occurrenceDir = path.join(occurrenceRoot, id);
    fs.mkdirSync(occurrenceDir, { recursive: true });
    const savedAttachments = attachments.map((attachment, index) => {
      if (!attachment?.base64 || !attachment?.mimeType) {
        throw new Error('Uma das evidências está incompleta.');
      }
      const bytes = Buffer.from(attachment.base64, 'base64');
      if (bytes.length === 0 || bytes.length > 18 * 1024 * 1024) {
        throw new Error('Uma evidência é vazia ou ultrapassa 18 MB.');
      }
      const fileName = `${String(index + 1).padStart(2, '0')}-${attachment.kind || 'evidence'}${safeExtension(attachment.mimeType)}`;
      fs.writeFileSync(path.join(occurrenceDir, fileName), bytes);
      return { fileName, mimeType: attachment.mimeType, bytes: bytes.length };
    });
    const receivedAt = new Date().toISOString();
    const record = {
      id,
      receivedAt,
      status: 'received',
      resident: { fullName: resident.fullName, phone: resident.phone },
      category: payload.category,
      description: String(payload.description).trim(),
      location: {
        latitude: location.latitude,
        longitude: location.longitude,
        accuracy: location.accuracy,
      },
      attachments: savedAttachments,
    };
    fs.writeFileSync(
      path.join(occurrenceDir, 'occurrence.json'),
      JSON.stringify(record, null, 2),
      'utf8',
    );
    response.writeHead(201, {
      'Content-Type': 'application/json; charset=utf-8',
      'Cache-Control': 'no-store',
    });
    response.end(JSON.stringify({ id, receivedAt }));
  } catch (error) {
    if (response.headersSent || response.destroyed) return;
    response.writeHead(400, {
      'Content-Type': 'application/json; charset=utf-8',
      'Cache-Control': 'no-store',
    });
    response.end(JSON.stringify({ error: error.message }));
  }
}

function serveStatic(requestPath, response) {
  const relative = requestPath === '/' ? 'index.html' : requestPath.slice(1);
  let filePath = path.resolve(webRoot, relative);
  if (!filePath.startsWith(webRoot)) {
    response.writeHead(403).end('Acesso negado');
    return;
  }
  if (!fs.existsSync(filePath) || fs.statSync(filePath).isDirectory()) {
    filePath = path.join(webRoot, 'index.html');
  }
  if (!fs.existsSync(filePath)) {
    response.writeHead(503, { 'Content-Type': 'text/plain; charset=utf-8' });
    response.end('Compile a versão web com: flutter build web --release');
    return;
  }
  response.writeHead(200, {
    'Content-Type': mimeTypes[path.extname(filePath)] || 'application/octet-stream',
  });
  fs.createReadStream(filePath).pipe(response);
}

const server = http.createServer(async (request, response) => {
  const requestUrl = new URL(request.url, `http://${request.headers.host}`);
  if (request.method === 'GET' && requestUrl.pathname === '/api/situacao') {
    await serveSituation(response);
  } else if (request.method === 'POST' && requestUrl.pathname === '/api/ocorrencias') {
    await receiveOccurrence(request, response);
  } else if (request.method === 'GET') {
    serveStatic(decodeURIComponent(requestUrl.pathname), response);
  } else {
    response.writeHead(405, { Allow: 'GET, POST' }).end('Método não permitido');
  }
});

server.listen(port, '127.0.0.1', () => {
  console.log(`BluAlert disponível em http://127.0.0.1:${port}`);
});
