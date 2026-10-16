const { loadHydrology, loadAlerts } = require('../server/data-api');

async function settle(loader, label) {
  try {
    return await loader();
  } catch (error) {
    // Falhas das fontes são independentes. O detalhe técnico não vai ao app.
    console.error(`Fonte ${label} indisponível:`, error);
    return { available: false, reason: 'Fonte temporariamente indisponível.' };
  }
}

async function handler(request, response) {
  if (request.method !== 'GET') {
    response.setHeader('Allow', 'GET');
    return response.status(405).json({ error: 'METHOD_NOT_ALLOWED' });
  }

  const [telemetry, rawMunicipal] = await Promise.all([
    settle(loadHydrology, 'ANA'),
    settle(loadAlerts, 'AlertaBlu'),
  ]);
  const municipal = rawMunicipal.available
    ? {
        ...rawMunicipal,
        regions: Object.fromEntries(
          (rawMunicipal.regions || []).map(({ region, stage }) => [region, stage]),
        ),
      }
    : rawMunicipal;
  const anyAvailable = telemetry.available || municipal.available;
  response.setHeader('Cache-Control', anyAvailable
    ? 'public, s-maxage=300, stale-while-revalidate=60'
    : 'no-store');
  return response.status(anyAvailable ? 200 : 503).json({
    fetchedAt: new Date().toISOString(),
    telemetry,
    municipal,
  });
}

module.exports = handler;
