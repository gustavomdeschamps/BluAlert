// GERADO a partir da fonte oficial. Não edite à mão.
//
// Origem: Prefeitura de Blumenau — servidor ArcGIS institucional
//   https://geo.blumenau.sc.gov.br/server/rest/services/Limites/Bairros/FeatureServer/0
//   camada GEO.BAIRROS, campos BAIRROS e CD_BAIRRO. A geometria é reprojetada
//   de EPSG:31982 para EPSG:4326 pelo próprio servidor (parâmetro outSR).
// Consultado em: 09/09/2026.
//
// `officialName` é o nome exatamente como a Prefeitura publica (sem acentos, em
// caixa alta). `displayName` restaura a acentuação para leitura — é normalização
// ortográfica de exibição, não alteração do dado oficial.
//
// `latitude`/`longitude` são o centroide do maior anel do polígono oficial:
// uma **coordenada de referência do bairro**. Não é sede, não é o centro exato
// e, sobretudo, **não é uma estação meteorológica** — não existe estação por
// bairro em Blumenau.

import 'neighborhoods.dart';

/// Os 35 bairros oficiais de Blumenau.
const List<Neighborhood> officialNeighborhoods = [
  Neighborhood(
    displayName: 'Água Verde',
    officialName: 'AGUA VERDE',
    officialCode: '18',
    latitude: -26.91086,
    longitude: -49.11992,
  ),
  Neighborhood(
    displayName: 'Badenfurt',
    officialName: 'BADENFURT',
    officialCode: '31',
    latitude: -26.88039,
    longitude: -49.14592,
  ),
  Neighborhood(
    displayName: 'Boa Vista',
    officialName: 'BOA VISTA',
    officialCode: '22',
    latitude: -26.90094,
    longitude: -49.06728,
  ),
  Neighborhood(
    displayName: 'Bom Retiro',
    officialName: 'BOM RETIRO',
    officialCode: '10',
    latitude: -26.92585,
    longitude: -49.07567,
  ),
  Neighborhood(
    displayName: 'Centro',
    officialName: 'CENTRO',
    officialCode: '2',
    latitude: -26.91875,
    longitude: -49.06968,
  ),
  Neighborhood(
    displayName: 'Da Glória',
    officialName: 'DA GLORIA',
    officialCode: '5',
    latitude: -26.96857,
    longitude: -49.05737,
  ),
  Neighborhood(
    displayName: 'Do Salto',
    officialName: 'DO SALTO',
    officialCode: '16',
    latitude: -26.8864,
    longitude: -49.1031,
  ),
  Neighborhood(
    displayName: 'Escola Agrícola',
    officialName: 'ESCOLA AGRICOLA',
    officialCode: '17',
    latitude: -26.89709,
    longitude: -49.1043,
  ),
  Neighborhood(
    displayName: 'Fidélis',
    officialName: 'FIDELIS',
    officialCode: '29',
    latitude: -26.83886,
    longitude: -49.06575,
  ),
  Neighborhood(
    displayName: 'Fortaleza',
    officialName: 'FORTALEZA',
    officialCode: '26',
    latitude: -26.86981,
    longitude: -49.06773,
  ),
  Neighborhood(
    displayName: 'Fortaleza Alta',
    officialName: 'FORTALEZA ALTA',
    officialCode: '28',
    latitude: -26.85216,
    longitude: -49.05415,
  ),
  Neighborhood(
    displayName: 'Garcia',
    officialName: 'GARCIA',
    officialCode: '4',
    latitude: -26.94202,
    longitude: -49.06332,
  ),
  Neighborhood(
    displayName: 'Itoupava Central',
    officialName: 'ITOUPAVA CENTRAL',
    officialCode: '34',
    latitude: -26.79405,
    longitude: -49.09072,
  ),
  Neighborhood(
    displayName: 'Itoupava Norte',
    officialName: 'ITOUPAVA NORTE',
    officialCode: '25',
    latitude: -26.88392,
    longitude: -49.07653,
  ),
  Neighborhood(
    displayName: 'Itoupava Seca',
    officialName: 'ITOUPAVA SECA',
    officialCode: '20',
    latitude: -26.89262,
    longitude: -49.08523,
  ),
  Neighborhood(
    displayName: 'Itoupavazinha',
    officialName: 'ITOUPAVAZINHA',
    officialCode: '33',
    latitude: -26.8527,
    longitude: -49.10995,
  ),
  Neighborhood(
    displayName: 'Jardim Blumenau',
    officialName: 'JARDIM BLUMENAU',
    officialCode: '9',
    latitude: -26.92915,
    longitude: -49.06433,
  ),
  Neighborhood(
    displayName: 'Nova Esperança',
    officialName: 'NOVA ESPERANCA',
    officialCode: '24',
    latitude: -26.8879,
    longitude: -49.0522,
  ),
  Neighborhood(
    displayName: 'Passo Manso',
    officialName: 'PASSO MANSO',
    officialCode: '14',
    latitude: -26.91209,
    longitude: -49.1503,
  ),
  Neighborhood(
    displayName: 'Ponta Aguda',
    officialName: 'PONTA AGUDA',
    officialCode: '23',
    latitude: -26.90337,
    longitude: -49.04597,
  ),
  Neighborhood(
    displayName: 'Progresso',
    officialName: 'PROGRESSO',
    officialCode: '6',
    latitude: -26.9818,
    longitude: -49.08318,
  ),
  Neighborhood(
    displayName: 'Ribeirão Fresco',
    officialName: 'RIBEIRAO FRESCO',
    officialCode: '3',
    latitude: -26.92727,
    longitude: -49.04413,
  ),
  Neighborhood(
    displayName: 'Salto do Norte',
    officialName: 'SALTO DO NORTE',
    officialCode: '30',
    latitude: -26.87177,
    longitude: -49.10724,
  ),
  Neighborhood(
    displayName: 'Salto Weissbach',
    officialName: 'SALTO WEISSBACH',
    officialCode: '15',
    latitude: -26.89767,
    longitude: -49.12845,
  ),
  Neighborhood(
    displayName: 'Testo Salto',
    officialName: 'TESTO SALTO',
    officialCode: '32',
    latitude: -26.85313,
    longitude: -49.15663,
  ),
  Neighborhood(
    displayName: 'Tribess',
    officialName: 'TRIBESS',
    officialCode: '27',
    latitude: -26.87405,
    longitude: -49.05153,
  ),
  Neighborhood(
    displayName: 'Valparaíso',
    officialName: 'VALPARAISO',
    officialCode: '7',
    latitude: -26.95331,
    longitude: -49.0789,
  ),
  Neighborhood(
    displayName: 'Velha',
    officialName: 'VELHA',
    officialCode: '11',
    latitude: -26.92146,
    longitude: -49.10079,
  ),
  Neighborhood(
    displayName: 'Velha Central',
    officialName: 'VELHA CENTRAL',
    officialCode: '12',
    latitude: -26.93106,
    longitude: -49.13691,
  ),
  Neighborhood(
    displayName: 'Velha Grande',
    officialName: 'VELHA GRANDE',
    officialCode: '13',
    latitude: -26.94698,
    longitude: -49.13106,
  ),
  Neighborhood(
    displayName: 'Victor Konder',
    officialName: 'VICTOR KONDER',
    officialCode: '21',
    latitude: -26.90871,
    longitude: -49.07442,
  ),
  Neighborhood(
    displayName: 'Vila Formosa',
    officialName: 'VILA FORMOSA',
    officialCode: '8',
    latitude: -26.93777,
    longitude: -49.0726,
  ),
  Neighborhood(
    displayName: 'Vila Itoupava',
    officialName: 'VILA ITOUPAVA',
    officialCode: '35',
    latitude: -26.73043,
    longitude: -49.06744,
  ),
  Neighborhood(
    displayName: 'Vila Nova',
    officialName: 'VILA NOVA',
    officialCode: '19',
    latitude: -26.90566,
    longitude: -49.08904,
  ),
  Neighborhood(
    displayName: 'Vorstadt',
    officialName: 'VORSTADT',
    officialCode: '1',
    latitude: -26.9086,
    longitude: -49.03699,
  ),
];
