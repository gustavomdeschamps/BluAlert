const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { webcrypto } = require('node:crypto');
const ts = require('../../operator-panel/node_modules/typescript');

function handler(name, client) {
  let serve;
  const source = fs.readFileSync(path.join(__dirname, name, 'index.ts'), 'utf8');
  const code = ts.transpileModule(source, {compilerOptions: {module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022}}).outputText;
  vm.runInNewContext(code, {
    exports: {}, Response, crypto: webcrypto,
    Deno: {serve: callback => { serve = callback; }},
    require: dependency => dependency.includes('cors')
      ? {corsHeadersFor: () => ({})}
      : {
        authenticatedUser: async () => ({client, user: {id: 'reporter'}}),
        json: (body, status) => Response.json(body, {status}),
      },
  });
  return serve;
}

test('as duas funções recusam métodos de escrita incorretos', async () => {
  for (const name of ['occurrence-session', 'occurrence-confirm']) {
    const response = await handler(name, {})(new Request('http://localhost', {method: 'DELETE'}));
    assert.equal(response.status, 405);
  }
});

test('hash diferente impede que a ocorrência seja marcada como recebida', async () => {
  let updated = false;
  const occurrence = {id: 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee', status: 'uploading'};
  const media = {kind: 'photo', object_path: 'reporter/occurrence/photo.jpg', byte_size: 3, sha256: '0'.repeat(64)};
  const client = {
    from: table => {
      const query = {
        select: () => query,
        eq: () => query,
        maybeSingle: async () => ({data: occurrence}),
        then: resolve => resolve({data: [media]}),
        update: () => { updated = true; throw new Error('Não deve confirmar'); },
      };
      return query;
    },
    storage: {from: () => ({
      list: async () => ({data: [{name: 'photo.jpg', metadata: {size: 3}}]}),
      download: async () => ({data: new Blob([new Uint8Array([1, 2, 3])])}),
    })},
  };
  const response = await handler('occurrence-confirm', client)(new Request('http://localhost', {
    method: 'POST', body: JSON.stringify({occurrenceId: occurrence.id}),
  }));
  assert.equal(response.status, 409);
  assert.equal((await response.json()).error, 'INVALID_MEDIA');
  assert.equal(updated, false);
});
