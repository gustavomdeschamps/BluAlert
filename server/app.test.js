const { test, before, after } = require('node:test');
const assert = require('node:assert/strict');
const http = require('node:http');
const server = require('./app');

before(() => new Promise(resolve => server.listen(0, '127.0.0.1', resolve)));
after(() => new Promise(resolve => server.close(resolve)));

function request(path, method = 'GET') {
  return new Promise((resolve, reject) => {
    const req = http.request({host: '127.0.0.1', port: server.address().port, path, method}, response => {
      response.resume();
      response.on('end', () => resolve(response.statusCode));
    });
    req.on('error', reject);
    req.end();
  });
}

test('URL malformada não derruba o servidor', async () => {
  assert.equal(await request('/%ZZ'), 400);
  assert.ok([200, 503].includes(await request('/')));
});
test('não permite acessar uma pasta irmã com o mesmo prefixo', async () => {
  assert.equal(await request('/..%2fweb-private%2fsegredo.txt'), 403);
});
test('recusa gravações pelo servidor estático', async () => {
  assert.equal(await request('/', 'POST'), 405);
});
