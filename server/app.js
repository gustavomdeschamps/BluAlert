// Servidor estático local da build web do BluAlert.
//
// Este processo **não** consulta fontes oficiais e **não** recebe ocorrências.
//
// Antes havia aqui um `/api/situacao` que raspava a página da Defesa Civil.
// Ele foi removido por dois motivos apurados na auditoria:
//
//  1. A página consultada era `/c/meteorologia/aplicativo` — a página "sobre o
//     aplicativo", que não contém os valores. Os padrões casavam apenas com
//     itens do menu de navegação, sem número algum.
//  2. O servidor da Prefeitura entrega uma cadeia TLS incompleta, e o Node
//     falhava com UNABLE_TO_VERIFY_LEAF_SIGNATURE mesmo com `--use-system-ca`.
//
// Hoje a leitura das fontes oficiais vive na Edge Function `situation`, que
// injeta o certificado intermediário ausente, normaliza os campos e serve tanto
// o Android quanto a web. Ver `supabase/functions/situation/index.ts` e
// `docs/fontes-de-dados.md`.
const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');

const port = Number(process.env.PORT || 3000);
const webRoot = path.resolve(__dirname, '..', 'build', 'web');

const mimeTypes = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.png': 'image/png',
  '.otf': 'font/otf',
  '.ttf': 'font/ttf',
  '.woff2': 'font/woff2',
  '.svg': 'image/svg+xml',
  '.wasm': 'application/wasm',
};

function serveStatic(requestPath, response) {
  const relative = requestPath === '/' ? 'index.html' : requestPath.slice(1);
  let filePath = path.resolve(webRoot, relative);
  const withinRoot = path.relative(webRoot, filePath);
  if (withinRoot.startsWith('..') || path.isAbsolute(withinRoot)) {
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
    'Cache-Control': 'no-store, max-age=0',
  });
  const stream = fs.createReadStream(filePath);
  stream.on('error', () => response.destroy());
  stream.pipe(response);
}

const server = http.createServer((request, response) => {
  let requestPath;
  try {
    requestPath = decodeURIComponent(new URL(request.url, 'http://localhost').pathname);
  } catch {
    response.writeHead(400).end('Endereço inválido');
    return;
  }
  if (request.method === 'GET') {
    serveStatic(requestPath, response);
  } else {
    response.writeHead(405, { Allow: 'GET' }).end('Método não permitido');
  }
});

if (require.main === module) {
  server.listen(port, '127.0.0.1', () => {
    console.log(`BluAlert disponível em http://127.0.0.1:${server.address().port}`);
  });
}
module.exports = server;
