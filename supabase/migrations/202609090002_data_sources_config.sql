-- Configuração remota das fontes de dados.
--
-- Permite ajustar provedores, cache e camadas sem republicar o aplicativo. O
-- cliente sempre tem um valor local seguro para cada campo, de modo que o
-- backend indisponível nunca deixa a interface sem comportamento definido.

alter table public.remote_config
  -- Duração do cache em segundos, por família de dado.
  add column if not exists weather_cache_seconds integer not null default 1800
    check (weather_cache_seconds between 300 and 21600),
  add column if not exists hydrology_cache_seconds integer not null default 1800
    check (hydrology_cache_seconds between 300 and 21600),

  -- Liga e desliga a previsão por bairro sem nova publicação.
  add column if not exists neighborhood_forecast_enabled boolean not null default true,

  -- Camadas do mapa. Permanecem desligadas enquanto não houver fonte oficial
  -- utilizável; ligar uma camada sem GeoJSON licenciado desenharia invenção.
  add column if not exists landslide_layer_enabled boolean not null default false,
  add column if not exists flood_layer_enabled boolean not null default false,

  -- Aviso de indisponibilidade exibido no topo da situação, quando preenchido.
  add column if not exists data_notice text,

  -- Manutenção programada: a interface avisa antes de a fonte cair.
  add column if not exists maintenance_notice text,

  -- Links oficiais, para corrigir uma URL que mude sem republicar o app.
  add column if not exists alertablu_url text not null
    default 'https://defesacivil.blumenau.sc.gov.br/d/nivel-do-rio',
  add column if not exists river_criteria_url text not null
    default 'https://defesacivil.blumenau.sc.gov.br/c/meteorologia/legenda_nivel_rio',

  -- Provedor de tiles ativo. Vazio significa OpenStreetMap padrão.
  add column if not exists map_tile_url text,
  add column if not exists map_tile_attribution text,

  -- Estação hidrológica de referência. Se a ANA desativar a atual, a troca é
  -- feita aqui, sem nova versão do aplicativo.
  add column if not exists hydrology_station_code text not null default '83800010',
  add column if not exists hydrology_station_name text not null
    default 'PCH Salto Jusante';

comment on column public.remote_config.landslide_layer_enabled is
  'Só ative com GeoJSON oficial e licenciado da Prefeitura. Camada sem fonte deve permanecer desativada e identificada como indisponível.';
comment on column public.remote_config.hydrology_station_code is
  'Código ANA da estação fluviométrica telemétrica de referência em Blumenau.';
