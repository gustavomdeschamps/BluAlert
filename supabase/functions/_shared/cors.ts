// Origens autorizadas a chamar as funções pelo navegador.
// A build web do Flutter e o painel rodam em origens diferentes; qualquer uma
// fora desta lista recebe resposta sem cabeçalho de CORS e é bloqueada pelo
// próprio navegador. Configure ALLOWED_ORIGINS como lista separada por vírgula.
const configuredOrigins = (Deno.env.get('ALLOWED_ORIGINS') ?? '')
  .split(',')
  .map((value) => value.trim())
  .filter((value) => value.length > 0);

const developmentOrigins = [
  'http://localhost:3000',
  'http://127.0.0.1:3000',
  'http://localhost:5173',
  'http://127.0.0.1:5173',
];

const allowedOrigins = new Set(
  configuredOrigins.length > 0 ? configuredOrigins : developmentOrigins,
);

/// Cabeçalhos de CORS para a origem da requisição, quando ela for autorizada.
/// Precisam acompanhar **todas** as respostas, não apenas o preflight: sem
/// `Access-Control-Allow-Origin` na resposta real o navegador descarta o corpo
/// e o aplicativo web nunca recebe a confirmação da central.
export function corsHeadersFor(request: Request): Record<string, string> {
  const origin = request.headers.get('Origin');
  if (origin === null) return {}; // Chamada nativa (Android): CORS não se aplica.
  if (!allowedOrigins.has(origin)) return {};
  return {
    'Access-Control-Allow-Origin': origin,
    'Access-Control-Allow-Headers':
      'authorization, apikey, content-type, x-client-info',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Access-Control-Max-Age': '86400',
    Vary: 'Origin',
  };
}
