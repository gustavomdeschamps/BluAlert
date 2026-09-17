// Servidor de dados do BluAlert (desenvolvimento).
//
// Existe porque duas fontes oficiais **não podem** ser consultadas direto pelo
// navegador nem pelo Dart:
//
//  - ANA e Defesa Civil de Blumenau não enviam cabeçalho de CORS;
//  - o servidor da Prefeitura entrega uma cadeia TLS incompleta, e Node/Dart
//    falham com UNABLE_TO_VERIFY_LEAF_SIGNATURE (ver server/certs/).
//
// A meteorologia **não** passa por aqui: o Open-Meteo envia CORS `*` e é
// consultado direto pelo Flutter. Isso é deliberado — se este servidor não
// estiver rodando, a previsão do tempo continua funcionando no aplicativo.
//
// Em produção o mesmo contrato é servido pela Edge Function `situation`.
const http = require('node:http');
const https = require('node:https');
const fs = require('node:fs');
const path = require('node:path');
const tls = require('node:tls');

const PORT = Number(process.env.DATA_API_PORT || 3001);
const VERSION = '1.0.0';
const STARTED_AT = new Date().toISOString();

// ---------------------------------------------------------------------------
// Códigos de motivo normalizados. A interface traduz cada um; o texto técnico
// (exceção, stack, corpo da resposta) fica só no log do servidor.
// ---------------------------------------------------------------------------
const REASON = {
  UPSTREAM_TIMEOUT: 'UPSTREAM_TIMEOUT',
  UPSTREAM_HTTP_ERROR: 'UPSTREAM_HTTP_ERROR',
  INVALID_RESPONSE: 'INVALID_RESPONSE',
  NO_CURRENT_DATA: 'NO_CURRENT_DATA',
  NETWORK_OFFLINE: 'NETWORK_OFFLINE',
};

/// Estação fluviométrica telemétrica da ANA no Itajaí-Açu, em Blumenau.
///
/// Escolhida por inventário (HidroInventario, município BLUMENAU), não por
/// suposição: "Itajaí-Açu" não identifica uma estação — o rio atravessa vários
/// municípios. A 83800002 ("BLUMENAU (PCD)") consta do inventário mas não
/// devolve leituras.
const ANA_STATION = {
  code: '83800010',
  name: 'PCH Salto Jusante',
  municipality: 'Blumenau',
  river: 'Itajaí-Açu',
  latitude: -26.9175,
  longitude: -49.0661,
  /// A ANA devolve o nível em centímetros. A conversão para metros é explícita
  /// e testada; a unidade original fica registrada na resposta.
  upstreamUnit: 'cm',
  unit: 'm',
};

const ANA_BASE = 'https://telemetriaws1.ana.gov.br/ServiceANA.asmx';
const ANA_OFFICIAL_URL = 'https://www.snirh.gov.br/hidrotelemetria/';
const ALERTABLU_URL = 'https://defesacivil.blumenau.sc.gov.br/d/nivel-do-rio';
const ALERTABLU_CRITERIA_URL =
  'https://defesacivil.blumenau.sc.gov.br/c/meteorologia/legenda_nivel_rio';

// Faixa plausível do nível, em metros. Descarta sentinela (-9999) e corrupção
// antes que virem "nível do rio" na tela de alguém.
const LEVEL_MIN_M = 0;
const LEVEL_MAX_M = 20;

const TIMEOUT_MS = 12000;
const CACHE_TTL_MS = 5 * 60 * 1000;

// Agente TLS com as raízes do sistema **mais** o intermediário ausente. A
// verificação continua completa.
const intermediate = fs.readFileSync(
  path.join(__dirname, 'certs', 'sectigo-intermediate.pem'),
  'utf8',
);
const blumenauAgent = new https.Agent({
  ca: [...tls.rootCertificates, intermediate],
  keepAlive: false,
});

// ---------------------------------------------------------------------------
// Estado observável, exposto em /health.
// ---------------------------------------------------------------------------
const health = {
  hydrology: { status: 'unknown', lastAttemptAt: null, lastSuccessAt: null, reasonCode: null },
  alerts: { status: 'unknown', lastAttemptAt: null, lastSuccessAt: null, reasonCode: null },
};

const cache = new Map();

function cached(key) {
  const entry = cache.get(key);
  if (!entry) return null;
  const ageMs = Date.now() - entry.storedAt;
  return { ...entry, ageMs, expired: ageMs > CACHE_TTL_MS };
}

function store(key, payload) {
  cache.set(key, { payload, storedAt: Date.now() });
}

function log(...parts) {
  console.log(`[${new Date().toISOString()}]`, ...parts);
}

/// GET com timeout explícito. Devolve `{ ok, status, body }` ou lança um erro
/// já classificado em `code`.
function fetchText(url, { useBlumenauAgent = false } = {}) {
  return new Promise((resolve, reject) => {
    const options = {
      headers: {
        Accept: 'text/html,application/xml,text/xml,*/*',
        'User-Agent': 'BluAlert/1.0 (piloto Defesa Civil Blumenau)',
      },
      timeout: TIMEOUT_MS,
    };
    if (useBlumenauAgent) options.agent = blumenauAgent;

    const request = https.get(url, options, (response) => {
      const { statusCode } = response;
      if (statusCode !== 200) {
        response.resume();
        const error = new Error(`HTTP ${statusCode}`);
        error.code = REASON.UPSTREAM_HTTP_ERROR;
        error.httpStatus = statusCode;
        reject(error);
        return;
      }
      let body = '';
      response.setEncoding('utf8');
      response.on('data', (chunk) => (body += chunk));
      response.on('end', () => resolve(body));
    });

    request.on('timeout', () => {
      request.destroy();
      const error = new Error('timeout');
      error.code = REASON.UPSTREAM_TIMEOUT;
      reject(error);
    });
    request.on('error', (cause) => {
      const error = new Error(cause.message);
      // DNS ou rede fora distinguem-se de erro da fonte.
      error.code =
        cause.code === 'ENOTFOUND' || cause.code === 'EAI_AGAIN'
          ? REASON.NETWORK_OFFLINE
          : REASON.UPSTREAM_HTTP_ERROR;
      error.cause = cause;
      reject(error);
    });
  });
}

function twoDigits(value) {
  return String(value).padStart(2, '0');
}

/// A ANA espera dd/MM/yyyy.
function anaDate(date) {
  return `${twoDigits(date.getUTCDate())}/${twoDigits(date.getUTCMonth() + 1)}/${date.getUTCFullYear()}`;
}

function tagValue(block, tag) {
  const match = block.match(new RegExp(`<${tag}>([\\s\\S]*?)</${tag}>`));
  return match ? match[1].trim() : null;
}

/// Converte centímetros da ANA para metros. Isolado para ser testável.
function centimetersToMeters(raw) {
  const centimeters = Number(raw);
  if (!Number.isFinite(centimeters)) return null;
  const meters = centimeters / 100;
  if (meters < LEVEL_MIN_M || meters > LEVEL_MAX_M) return null;
  return Math.round(meters * 1000) / 1000;
}

/// Interpreta a resposta XML da ANA. Exportado para os testes de parser.
function parseAnaReadings(body) {
  const failure = body.match(/<Error>([\s\S]*?)<\/Error>/);
  if (failure) {
    const error = new Error(failure[1].trim());
    error.code = REASON.NO_CURRENT_DATA;
    throw error;
  }
  const readings = [];
  for (const block of body.split('<DataHora>').slice(1)) {
    const at = block.split('</DataHora>')[0].trim();
    const meters = centimetersToMeters(tagValue(block, 'Nivel'));
    if (!at || meters === null) continue;
    // A ANA publica em horário local sem fuso; normalizamos o separador.
    readings.push({ at: at.replace(' ', 'T'), meters });
  }
  if (readings.length === 0) {
    const error = new Error('sem leituras válidas');
    error.code = REASON.NO_CURRENT_DATA;
    throw error;
  }
  readings.sort((a, b) => a.at.localeCompare(b.at));
  return readings;
}

/// Interpreta a página da Defesa Civil. Exportado para os testes de parser.
function parseAlertaBlu(html) {
  const text = html
    .replace(/<script[\s\S]*?<\/script>/gi, ' ')
    .replace(/<style[\s\S]*?<\/style>/gi, ' ')
    .replace(/<[^>]+>/g, '|')
    .replace(/&nbsp;/g, ' ')
    .replace(/&ccedil;/g, 'ç')
    .replace(/&atilde;/g, 'ã')
    .replace(/&aacute;/g, 'á')
    .replace(/&iacute;/g, 'í')
    .replace(/&uacute;/g, 'ú')
    .replace(/&eacute;/g, 'é')
    .replace(/(\|\s*)+/g, '|')
    .replace(/[ \t]+/g, ' ');

  const levelMatch = text.match(/N[íi]vel do Rio\s*\|\s*([0-9]+[,.][0-9]+)\s*m/i);
  let levelMeters = null;
  if (levelMatch) {
    const parsed = Number(levelMatch[1].replace(',', '.'));
    if (Number.isFinite(parsed) && parsed >= LEVEL_MIN_M && parsed <= LEVEL_MAX_M) {
      levelMeters = parsed;
    }
  }
  const publishedMatch = text.match(
    /Situa[çc][ãa]o publicada em\s*\|?\s*([0-9]{2}\/[0-9]{2}\/[0-9]{4})/i,
  );
  const stageMatch = text.match(
    /Itaja[íi]-A[çc]u\s*\|\s*(Normalidade|Observa[çc][ãa]o|Aten[çc][ãa]o|Alerta M[áa]ximo|Alerta)/i,
  );

  const regions = [];
  const block = text.match(/Condi[çc][õo]es Meteorol[óo]gicas([\s\S]{0,400})/i);
  if (block) {
    const pattern =
      /(Central|Leste|Norte|Oeste|Sul)\s*\|\s*(Normalidade|Observa[çc][ãa]o|Aten[çc][ãa]o|Alerta M[áa]ximo|Alerta)/gi;
    let hit;
    while ((hit = pattern.exec(block[1])) !== null) {
      regions.push({ region: hit[1], stage: hit[2] });
    }
  }

  if (levelMeters === null && !stageMatch && regions.length === 0) {
    // A página mudou a ponto de nada ser reconhecido: melhor admitir.
    const error = new Error('estrutura da página não reconhecida');
    error.code = REASON.INVALID_RESPONSE;
    throw error;
  }
  return {
    levelMeters,
    publishedAt: publishedMatch ? publishedMatch[1] : null,
    riverStage: stageMatch ? stageMatch[1] : null,
    regions,
  };
}

// ---------------------------------------------------------------------------
// Provedores. Cada um falha por conta própria.
// ---------------------------------------------------------------------------
async function loadHydrology() {
  const attemptedAt = new Date().toISOString();
  health.hydrology.lastAttemptAt = attemptedAt;
  const now = new Date();
  const start = new Date(now.getTime() - 48 * 3600 * 1000);
  const url =
    `${ANA_BASE}/DadosHidrometeorologicos?codEstacao=${ANA_STATION.code}` +
    `&dataInicio=${anaDate(start)}&dataFim=${anaDate(now)}`;

  const body = await fetchText(url);
  const readings = parseAnaReadings(body);
  const latest = readings[readings.length - 1];

  health.hydrology.status = 'available';
  health.hydrology.lastSuccessAt = new Date().toISOString();
  health.hydrology.reasonCode = null;

  return {
    available: true,
    station: ANA_STATION,
    source: 'Agência Nacional de Águas e Saneamento Básico (ANA)',
    officialUrl: ANA_OFFICIAL_URL,
    unit: ANA_STATION.unit,
    upstreamUnit: ANA_STATION.upstreamUnit,
    latest,
    readings,
    fetchedAt: new Date().toISOString(),
  };
}

async function loadAlerts() {
  const attemptedAt = new Date().toISOString();
  health.alerts.lastAttemptAt = attemptedAt;

  const html = await fetchText(ALERTABLU_URL, { useBlumenauAgent: true });
  const parsed = parseAlertaBlu(html);

  health.alerts.status = 'available';
  health.alerts.lastSuccessAt = new Date().toISOString();
  health.alerts.reasonCode = null;

  return {
    available: true,
    source: 'Defesa Civil de Blumenau — AlertaBlu',
    officialUrl: ALERTABLU_URL,
    criteriaUrl: ALERTABLU_CRITERIA_URL,
    unit: 'm',
    ...parsed,
    fetchedAt: new Date().toISOString(),
  };
}

/// Executa um provedor sem deixar a falha escapar, e reaproveita o cache
/// vencido **marcado como vencido** — nunca apresentado como atual.
async function runProvider(key, loader) {
  try {
    const payload = await loader();
    store(key, payload);
    return payload;
  } catch (error) {
    const reasonCode = error.code || REASON.INVALID_RESPONSE;
    health[key].status = 'unavailable';
    health[key].reasonCode = reasonCode;
    // Detalhe técnico só aqui.
    log(`falha em ${key}: ${reasonCode} — ${error.message}`);

    const previous = cached(key);
    if (previous) {
      return {
        ...previous.payload,
        available: true,
        stale: true,
        cacheAgeSeconds: Math.round(previous.ageMs / 1000),
        reasonCode,
      };
    }
    return { available: false, reasonCode };
  }
}

function json(response, status, body, extraHeaders = {}) {
  response.writeHead(status, {
    'Content-Type': 'application/json; charset=utf-8',
    'Cache-Control': 'no-store',
    // Servidor de desenvolvimento local: liberado para a origem do Flutter Web.
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'content-type',
    'Access-Control-Allow-Methods': 'GET, OPTIONS',
    ...extraHeaders,
  });
  response.end(JSON.stringify(body));
}

const server = http.createServer(async (request, response) => {
  const url = new URL(request.url, `http://${request.headers.host}`);

  if (request.method === 'OPTIONS') {
    json(response, 204, {});
    return;
  }
  if (request.method !== 'GET') {
    json(response, 405, { error: 'METHOD_NOT_ALLOWED' });
    return;
  }

  // --- Saúde -------------------------------------------------------------
  if (url.pathname === '/health') {
    const hydro = cached('hydrology');
    const alerts = cached('alerts');
    const statuses = [health.hydrology.status, health.alerts.status];
    const overall = statuses.every((s) => s === 'available')
      ? 'ok'
      : statuses.every((s) => s === 'unavailable')
        ? 'down'
        : 'degraded';
    json(response, 200, {
      status: overall,
      version: VERSION,
      startedAt: STARTED_AT,
      time: new Date().toISOString(),
      cacheTtlSeconds: CACHE_TTL_MS / 1000,
      services: {
        hydrology: {
          ...health.hydrology,
          station: ANA_STATION.code,
          cacheAgeSeconds: hydro ? Math.round(hydro.ageMs / 1000) : null,
        },
        alerts: {
          ...health.alerts,
          cacheAgeSeconds: alerts ? Math.round(alerts.ageMs / 1000) : null,
        },
        weather: {
          status: 'not_proxied',
          note: 'Open-Meteo envia CORS e é consultado direto pelo aplicativo.',
        },
      },
    });
    return;
  }

  // --- Fontes independentes ----------------------------------------------
  if (url.pathname === '/api/hydrology') {
    const payload = await runProvider('hydrology', loadHydrology);
    json(response, payload.available ? 200 : 503, payload);
    return;
  }
  if (url.pathname === '/api/alerts') {
    const payload = await runProvider('alerts', loadAlerts);
    json(response, payload.available ? 200 : 503, payload);
    return;
  }

  // --- Agregado -----------------------------------------------------------
  // Falhas independentes: uma fonte fora não derruba a outra. Nada de
  // Promise.all que rejeite o conjunto — cada provedor já captura a própria
  // falha e devolve o motivo.
  if (url.pathname === '/api/situation') {
    const [hydrology, alerts] = await Promise.all([
      runProvider('hydrology', loadHydrology),
      runProvider('alerts', loadAlerts),
    ]);
    const anyAvailable = hydrology.available || alerts.available;
    json(response, anyAvailable ? 200 : 503, {
      fetchedAt: new Date().toISOString(),
      telemetry: hydrology,
      municipal: alerts,
    });
    return;
  }

  json(response, 404, { error: 'NOT_FOUND' });
});

server.on('error', (error) => {
  if (error.code === 'EADDRINUSE') {
    console.error(
      `\n  A porta ${PORT} já está ocupada.\n` +
        `  Feche o processo que a está usando ou defina outra porta:\n` +
        `      set DATA_API_PORT=3002\n`,
    );
    process.exit(2);
  }
  console.error('Falha no servidor de dados:', error.message);
  process.exit(1);
});

if (require.main === module) {
  server.listen(PORT, '127.0.0.1', () => {
    log(`Servidor de dados do BluAlert em http://127.0.0.1:${PORT}`);
    log(`Saúde: http://127.0.0.1:${PORT}/health`);
  });
}

module.exports = {
  parseAnaReadings,
  parseAlertaBlu,
  centimetersToMeters,
  REASON,
  ANA_STATION,
};
