import { corsHeadersFor } from '../_shared/cors.ts';
import { json } from '../_shared/client.ts';
import { SECTIGO_INTERMEDIATE_PEM } from '../_shared/sectigo.ts';

// Situação hidrológica de Blumenau, normalizada para o aplicativo.
//
// Esta função existe por dois motivos concretos, ambos verificados:
//
// 1. Nenhuma das duas fontes envia cabeçalho de CORS, então a build web não
//    consegue consultá-las diretamente.
// 2. O servidor da Prefeitura envia uma cadeia TLS incompleta (falta o
//    intermediário Sectigo). Ver `_shared/sectigo.ts`.
//
// As falhas são independentes: se a ANA cair, a publicação municipal ainda é
// devolvida, e vice-versa. O aplicativo decide o que mostrar com o que chegou.

/// Estação telemétrica da ANA no Itajaí-Açu em Blumenau.
///
/// Escolhida por inventário (HidroInventario, município BLUMENAU): é a única
/// fluviométrica telemétrica com dados correntes no perímetro urbano. A estação
/// 83800002 ("BLUMENAU (PCD)") consta do inventário mas não devolve leituras.
const ANA_STATION = {
  code: '83800010',
  name: 'PCH Salto Jusante',
  latitude: -26.9175,
  longitude: -49.0661,
};

const ANA_BASE = 'https://telemetriaws1.ana.gov.br/ServiceANA.asmx';
const ALERTABLU_LEVEL_URL =
  'https://defesacivil.blumenau.sc.gov.br/d/nivel-do-rio';
const ALERTABLU_SOURCE_URL =
  'https://defesacivil.blumenau.sc.gov.br/c/meteorologia/legenda_nivel_rio';

/// Faixa plausível para o nível do rio, em metros. Descarta sentinela da fonte
/// (-9999) e leitura corrompida antes de chegar ao aplicativo.
const LEVEL_MIN_M = 0;
const LEVEL_MAX_M = 20;

/// Cliente HTTP que confia nas raízes do sistema **mais** o intermediário
/// ausente. A verificação continua completa.
function blumenauClient(): Deno.HttpClient {
  return Deno.createHttpClient({
    caCerts: [SECTIGO_INTERMEDIATE_PEM],
  });
}

function twoDigits(value: number): string {
  return value.toString().padStart(2, '0');
}

/// A ANA espera dd/MM/yyyy.
function anaDate(date: Date): string {
  return `${twoDigits(date.getUTCDate())}/${twoDigits(date.getUTCMonth() + 1)}/${date.getUTCFullYear()}`;
}

function tagValue(block: string, tag: string): string | null {
  const match = block.match(new RegExp(`<${tag}>([\\s\\S]*?)</${tag}>`));
  return match ? match[1].trim() : null;
}

interface Reading {
  at: string;
  meters: number;
}

/// Telemetria horária da ANA, das últimas ~48 h.
///
/// A série serve para o gráfico e para a tendência. Sem série real não há
/// tendência: o aplicativo mostra "tendência indisponível" em vez de adivinhar.
async function fetchAna(): Promise<
  { readings: Reading[] } | { error: string }
> {
  // A ANA serve cadeia TLS completa: usa o cliente padrão.
  try {
    const now = new Date();
    const start = new Date(now.getTime() - 48 * 3600 * 1000);
    const url =
      `${ANA_BASE}/DadosHidrometeorologicos?codEstacao=${ANA_STATION.code}` +
      `&dataInicio=${anaDate(start)}&dataFim=${anaDate(now)}`;
    const response = await fetch(url, {
      signal: AbortSignal.timeout(15000),
      headers: { Accept: 'text/xml' },
    });
    if (!response.ok) return { error: `ANA respondeu ${response.status}` };
    const body = await response.text();
    const failure = body.match(/<Error>([\s\S]*?)<\/Error>/);
    if (failure) return { error: failure[1].trim() };

    const readings: Reading[] = [];
    for (const block of body.split('<DataHora>').slice(1)) {
      const at = block.split('</DataHora>')[0].trim();
      const raw = tagValue(block, 'Nivel');
      if (!at || !raw) continue;
      const centimeters = Number(raw);
      if (!Number.isFinite(centimeters)) continue;
      const meters = centimeters / 100;
      // Descarta o implausível em vez de propagar para a tela.
      if (meters < LEVEL_MIN_M || meters > LEVEL_MAX_M) continue;
      readings.push({ at: at.replace(' ', 'T'), meters });
    }
    if (readings.length === 0) return { error: 'Sem leituras válidas.' };
    readings.sort((a, b) => a.at.localeCompare(b.at));
    return { readings };
  } catch (error) {
    return { error: error instanceof Error ? error.message : 'Falha na ANA' };
  }
}

/// Publicação municipal: nível divulgado e estágio por região.
///
/// A página é HTML server-rendered e não há endpoint JSON equivalente — foram
/// procurados API, feed e GeoJSON no domínio antes de recorrer à extração. Por
/// isso a leitura é tolerante: qualquer campo ausente vira `null` e o
/// aplicativo simplesmente não mostra aquele item, em vez de exibir lixo.
async function fetchAlertaBlu(): Promise<
  | {
      levelMeters: number | null;
      publishedAt: string | null;
      riverStage: string | null;
      regions: Record<string, string>;
    }
  | { error: string }
> {
  const client = blumenauClient();
  try {
    const response = await fetch(ALERTABLU_LEVEL_URL, {
      client,
      signal: AbortSignal.timeout(15000),
      headers: { Accept: 'text/html', 'User-Agent': 'BluAlert/1.0 (piloto Defesa Civil Blumenau)' },
    });
    if (!response.ok) {
      return { error: `AlertaBlu respondeu ${response.status}` };
    }
    const html = await response.text();
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
    let levelMeters: number | null = null;
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

    // Estágio meteorológico por região administrativa.
    const regions: Record<string, string> = {};
    const regionBlock = text.match(
      /Condi[çc][õo]es Meteorol[óo]gicas([\s\S]{0,400})/i,
    );
    if (regionBlock) {
      const pattern =
        /(Central|Leste|Norte|Oeste|Sul)\s*\|\s*(Normalidade|Observa[çc][ãa]o|Aten[çc][ãa]o|Alerta M[áa]ximo|Alerta)/gi;
      let hit: RegExpExecArray | null;
      while ((hit = pattern.exec(regionBlock[1])) !== null) {
        regions[hit[1]] = hit[2];
      }
    }

    if (levelMeters === null && stageMatch === null) {
      // A página mudou de estrutura: melhor admitir do que inventar.
      return { error: 'Estrutura da página oficial não reconhecida.' };
    }
    return {
      levelMeters,
      publishedAt: publishedMatch ? publishedMatch[1] : null,
      riverStage: stageMatch ? stageMatch[1] : null,
      regions,
    };
  } catch (error) {
    return {
      error: error instanceof Error ? error.message : 'Falha no AlertaBlu',
    };
  } finally {
    client.close();
  }
}

Deno.serve(async (request) => {
  const cors = corsHeadersFor(request);
  if (request.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers: cors });
  }

  const fetchedAt = new Date().toISOString();
  // Independentes de propósito: a queda de uma fonte não apaga a outra.
  const [ana, municipal] = await Promise.all([fetchAna(), fetchAlertaBlu()]);

  const body = {
    fetchedAt,
    telemetry: 'error' in ana
      ? { available: false, reason: ana.error }
      : {
          available: true,
          station: ANA_STATION,
          unit: 'm',
          source: 'Agência Nacional de Águas e Saneamento Básico (ANA)',
          officialUrl: 'https://www.snirh.gov.br/hidrotelemetria/',
          readings: ana.readings,
        },
    municipal: 'error' in municipal
      ? { available: false, reason: municipal.error }
      : {
          available: true,
          source: 'Defesa Civil de Blumenau — AlertaBlu',
          officialUrl: ALERTABLU_LEVEL_URL,
          criteriaUrl: ALERTABLU_SOURCE_URL,
          unit: 'm',
          ...municipal,
        },
  };

  const anyAvailable = body.telemetry.available || body.municipal.available;
  // 200 quando ao menos uma fonte respondeu; 503 só quando nada há para mostrar.
  return json(body, anyAvailable ? 200 : 503, {
    ...cors,
    'Cache-Control': 'public, max-age=300',
  });
});
