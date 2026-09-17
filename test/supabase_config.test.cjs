const { test, after } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'blualert-config-test-'));
after(() => fs.rmSync(directory, {recursive: true, force: true}));
const script = path.resolve(__dirname, '../configure-supabase.ps1');
function key(role, ref = 'classroom') {
  return `${Buffer.from('{}').toString('base64url')}.${Buffer.from(JSON.stringify({role, ref})).toString('base64url')}.test`;
}
function check(name, value) {
  const config = path.join(directory, `${name}.json`);
  if (value) fs.writeFileSync(config, JSON.stringify(value));
  return {config, result: spawnSync('powershell.exe', ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', script, '-CheckOnly', '-ConfigPath', config], {encoding: 'utf8'})};
}
test('aceita chave publica e preserva o arquivo existente', () => {
  const value = {SUPABASE_URL: 'https://classroom.supabase.co', SUPABASE_ANON_KEY: key('anon')};
  const {config, result} = check('anon', value);
  assert.equal(result.status, 0, result.stdout + result.stderr);
  assert.equal(fs.readFileSync(config, 'utf8'), JSON.stringify(value));
});
test('aceita o formato publishable', () => {
  assert.equal(check('publishable', {SUPABASE_URL: 'https://classroom.supabase.co', SUPABASE_ANON_KEY: 'sb_publishable_example'}).result.status, 0);
});
test('recusa chave privilegiada e token de usuario', () => {
  for (const publicKey of ['sb_secret_example', key('service_role'), key('authenticated')]) {
    assert.equal(check(`invalid-${publicKey.length}`, {SUPABASE_URL: 'https://classroom.supabase.co', SUPABASE_ANON_KEY: publicKey}).result.status, 1);
  }
});
test('recusa configuracao ausente e valores de exemplo', () => {
  assert.equal(check('missing').result.status, 1);
  assert.equal(check('placeholder', {SUPABASE_URL: 'https://SEU_PROJECT_REF.supabase.co', SUPABASE_ANON_KEY: 'SUA_CHAVE_ANON'}).result.status, 1);
});
test('recusa URL e chave de projetos diferentes', () => {
  assert.equal(check('mismatch', {SUPABASE_URL: 'https://another.supabase.co', SUPABASE_ANON_KEY: key('anon')}).result.status, 1);
});
