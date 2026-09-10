import React, { useEffect, useMemo, useRef, useState } from 'react';
import ReactDOM from 'react-dom/client';
import maplibregl from 'maplibre-gl';
import 'maplibre-gl/dist/maplibre-gl.css';
import './style.css';
import { supabase } from './supabase';
import type { QueueItem, Status } from './types';

const categoryName: Record<string, string> = {
  flood: 'Alagamento', landslide: 'Deslizamento', tree_or_road: 'Árvore ou via',
  structural_risk: 'Risco estrutural', other: 'Outro risco',
};
const priorityName = ['Sem classificação', 'Baixa', 'Moderada', 'Alta', 'Urgente', 'Crítica'];

const BLUMENAU = { lat: -26.9194, lon: -49.0661 };

/// Limite municipal oficial (IBGE, município 4202404). CORS aberto.
const IBGE_BOUNDARY_URL =
  'https://servicodados.ibge.gov.br/api/v3/malhas/municipios/4202404' +
  '?formato=application/vnd.geo+json&qualidade=maxima';

/// Estilo raster do OpenStreetMap.
///
/// Substitui o `demotiles.maplibre.org` que estava aqui antes: aquele é um
/// servidor de **demonstração** da MapLibre, com um mapa-múndi de baixo detalhe
/// e sem as ruas de Blumenau — não serve para operação e não é destinado a
/// produção.
///
/// A atribuição do OpenStreetMap é obrigatória e é renderizada pelo próprio
/// MapLibre a partir do campo `attribution`; não remova.
/// Para trocar de provedor, defina VITE_MAP_TILE_URL e VITE_MAP_ATTRIBUTION.
const tileUrl =
  import.meta.env.VITE_MAP_TILE_URL || 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
const tileAttribution =
  import.meta.env.VITE_MAP_ATTRIBUTION || '© OpenStreetMap contributors';

const OSM_STYLE: maplibregl.StyleSpecification = {
  version: 8,
  sources: {
    osm: {
      type: 'raster',
      tiles: [tileUrl],
      tileSize: 256,
      maxzoom: 19,
      attribution: tileAttribution,
    },
  },
  layers: [{ id: 'osm', type: 'raster', source: 'osm' }],
};

function Login() {
  const [email, setEmail] = useState(''); const [password, setPassword] = useState(''); const [error, setError] = useState('');
  async function submit(event: React.FormEvent) {
    event.preventDefault(); setError('');
    const result = await supabase.auth.signInWithPassword({ email, password });
    if (result.error) setError('Acesso não autorizado. Confira usuário e senha.');
  }
  return <main className="login-shell"><form className="login-card" onSubmit={submit}>
    <div className="brand-mark" aria-hidden="true">BA</div><p className="eyebrow">DEFESA CIVIL • BLUMENAU</p>
    <h1>Sala de Operações</h1><p className="subtle">Acesso restrito à equipe autorizada.</p>
    <label>E-mail<input type="email" autoComplete="username" value={email} onChange={e => setEmail(e.target.value)} required /></label>
    <label>Senha<input type="password" autoComplete="current-password" value={password} onChange={e => setPassword(e.target.value)} required /></label>
    {error && <p className="error" role="alert">{error}</p>}<button type="submit">Entrar no plantão</button>
  </form></main>;
}

function Operations() {
  const [items, setItems] = useState<QueueItem[]>([]); const [selected, setSelected] = useState<string | null>(null);
  const [connection, setConnection] = useState<'live'|'recovering'>('recovering'); const [error, setError] = useState('');
  const current = items.find(item => item.id === selected) ?? null;
  async function load() {
    const { data, error } = await supabase.from('operation_queue').select('*').order('effective_priority', { ascending: false }).order('created_at');
    if (error) setError('Não foi possível carregar a fila operacional.'); else { setItems((data ?? []) as QueueItem[]); setError(''); }
  }
  useEffect(() => {
    load();
    const channel = supabase.channel('operations').on('postgres_changes', { event: '*', schema: 'public', table: 'occurrences' }, load)
      .subscribe(status => setConnection(status === 'SUBSCRIBED' ? 'live' : 'recovering'));
    return () => { supabase.removeChannel(channel); };
  }, []);
  async function changeStatus(status: Status) {
    if (!current) return;
    const { error } = await supabase.rpc('change_occurrence_status', { target_occurrence: current.id, target_status: status, change_reason: 'Ação no painel operacional' });
    if (error) setError('A mudança não foi confirmada pelo servidor.'); else { await load(); if (status === 'resolved') setSelected(null); }
  }
  const sorted = useMemo(() => [...items].sort((a,b) => b.effective_priority-a.effective_priority || +new Date(a.created_at)-+new Date(b.created_at)), [items]);
  return <main className="ops-shell">
    <header><div><span className="signal-logo">BA</span><strong>BluAlert</strong><small>Sala de Operações</small></div>
      <div className="header-status"><span className={`connection ${connection}`}>{connection === 'live' ? 'Atualização em tempo real' : 'Reconectando'}</span><span className="pilot">VERSÃO PILOTO</span><button className="quiet" onClick={() => supabase.auth.signOut()}>Sair</button></div></header>
    {error && <div className="system-error" role="alert">{error} <button onClick={load}>Tentar novamente</button></div>}
    <section className="workspace">
      <Map items={items} selected={selected} onSelect={setSelected} />
      <aside className="queue"><div className="queue-title"><div><p className="eyebrow">FILA ATIVA</p><h2>{items.length} ocorrências</h2></div><button className="refresh" onClick={load} aria-label="Atualizar fila">↻</button></div>
        <div className="queue-list">{sorted.length === 0 ? <div className="empty"><strong>Nenhuma ocorrência ativa</strong><span>A conexão permanece aberta para novos registros.</span></div> : sorted.map(item => <button key={item.id} className={`queue-item p${item.effective_priority} ${selected === item.id ? 'selected' : ''}`} onClick={() => setSelected(item.id)}>
          <span className="priority">P{item.effective_priority} · {priorityName[item.effective_priority]}</span><strong>{categoryName[item.category]}</strong><span className="description">{item.description}</span>
          <span className="reason">{item.ordering_reason}</span><time>{new Date(item.created_at).toLocaleTimeString('pt-BR', {hour:'2-digit',minute:'2-digit'})}</time>
        </button>)}</div>
      </aside>
      {current && <Detail item={current} onClose={() => setSelected(null)} onStatus={changeStatus} />}
    </section>
  </main>;
}

function Map({ items, selected, onSelect }: { items: QueueItem[]; selected: string | null; onSelect: (id: string) => void }) {
  const host = useRef<HTMLDivElement>(null);
  const mapRef = useRef<maplibregl.Map | null>(null);
  const [styleReady, setStyleReady] = useState(false);
  const [boundaryReady, setBoundaryReady] = useState(false);

  useEffect(() => {
    if (!host.current || mapRef.current) return;
    const map = new maplibregl.Map({
      container: host.current,
      center: [BLUMENAU.lon, BLUMENAU.lat],
      zoom: 12,
      // Prende a operação ao município: sem isto dá para afastar até o
      // mapa-múndi, o que não ajuda o plantão e ainda consome tiles à toa.
      maxBounds: [[-49.30, -27.12], [-48.92, -26.68]],
      minZoom: 10.5,
      maxZoom: 19,
      style: OSM_STYLE,
    });
    mapRef.current = map;
    map.addControl(new maplibregl.NavigationControl({ showCompass: false }), 'bottom-left');
    map.addControl(new maplibregl.ScaleControl({ unit: 'metric' }), 'bottom-right');

    map.on('load', async () => {
      setStyleReady(true);
      // Limite municipal oficial do IBGE. Enquanto não carregar, nada é
      // desenhado — jamais um polígono aproximado.
      try {
        const response = await fetch(IBGE_BOUNDARY_URL, { signal: AbortSignal.timeout(15000) });
        if (!response.ok) return;
        const geojson = await response.json();
        if (!mapRef.current) return;
        map.addSource('limite-municipal', { type: 'geojson', data: geojson });
        map.addLayer({
          id: 'limite-municipal-linha',
          type: 'line',
          source: 'limite-municipal',
          paint: { 'line-color': '#f15d2a', 'line-width': 2, 'line-opacity': 0.85 },
        });
        setBoundaryReady(true);
      } catch {
        // Sem limite desenhado o mapa continua utilizável; não é bloqueante.
      }
    });

    return () => {
      mapRef.current = null;
      map.remove();
    };
  }, []);

  // Ocorrências em cluster. O MapLibre agrupa nativamente a partir de uma fonte
  // GeoJSON, sem biblioteca extra: numa enchente chegam dezenas de registros no
  // mesmo quarteirão e alfinetes soltos viram uma mancha ilegível.
  useEffect(() => {
    const map = mapRef.current;
    if (!map || !styleReady) return;

    const data: GeoJSON.FeatureCollection = {
      type: 'FeatureCollection',
      features: items.map((item) => ({
        type: 'Feature',
        geometry: { type: 'Point', coordinates: [item.longitude, item.latitude] },
        properties: {
          id: item.id,
          priority: item.effective_priority,
          selected: item.id === selected ? 1 : 0,
        },
      })),
    };

    const existing = map.getSource('ocorrencias') as maplibregl.GeoJSONSource | undefined;
    if (existing) {
      existing.setData(data);
      return;
    }

    map.addSource('ocorrencias', {
      type: 'geojson',
      data,
      cluster: true,
      clusterRadius: 45,
      clusterMaxZoom: 16,
      // Guarda a maior prioridade do grupo: um cluster que contém uma P5 não
      // pode parecer rotina.
      clusterProperties: { maxPriority: ['max', ['get', 'priority']] },
    });

    const byPriority = (field: string): maplibregl.ExpressionSpecification => [
      'match', ['get', field],
      5, '#c62035',
      4, '#df4b1c',
      3, '#c68a22',
      '#60798d',
    ];

    map.addLayer({
      id: 'clusters',
      type: 'circle',
      source: 'ocorrencias',
      filter: ['has', 'point_count'],
      paint: {
        'circle-color': byPriority('maxPriority'),
        'circle-radius': ['step', ['get', 'point_count'], 16, 5, 22, 15, 28],
        'circle-stroke-width': 3,
        'circle-stroke-color': '#ffffff',
      },
    });
    map.addLayer({
      id: 'clusters-count',
      type: 'symbol',
      source: 'ocorrencias',
      filter: ['has', 'point_count'],
      layout: { 'text-field': ['get', 'point_count_abbreviated'], 'text-size': 13 },
      paint: { 'text-color': '#ffffff' },
    });
    map.addLayer({
      id: 'ocorrencia',
      type: 'circle',
      source: 'ocorrencias',
      filter: ['!', ['has', 'point_count']],
      paint: {
        'circle-color': byPriority('priority'),
        'circle-radius': ['case', ['==', ['get', 'selected'], 1], 13, 9],
        'circle-stroke-width': ['case', ['==', ['get', 'selected'], 1], 4, 3],
        'circle-stroke-color': '#ffffff',
      },
    });

    map.on('click', 'ocorrencia', (event) => {
      const id = event.features?.[0]?.properties?.id;
      if (typeof id === 'string') onSelect(id);
    });
    // Clicar no cluster aproxima até ele se abrir.
    map.on('click', 'clusters', async (event) => {
      const feature = event.features?.[0];
      const clusterId = feature?.properties?.cluster_id;
      if (clusterId == null) return;
      const source = map.getSource('ocorrencias') as maplibregl.GeoJSONSource;
      const zoom = await source.getClusterExpansionZoom(clusterId as number);
      map.easeTo({
        center: (feature!.geometry as GeoJSON.Point).coordinates as [number, number],
        zoom,
      });
    });
    for (const layer of ['ocorrencia', 'clusters']) {
      map.on('mouseenter', layer, () => { map.getCanvas().style.cursor = 'pointer'; });
      map.on('mouseleave', layer, () => { map.getCanvas().style.cursor = ''; });
    }
  }, [items, selected, styleReady, onSelect]);

  return (
    <div className="map-wrap">
      <div className="map-label">
        <strong>Mapa operacional</strong>
        <span>
          {items.length === 0 ? 'Nenhuma ocorrência ativa' : `${items.length} ocorrência${items.length === 1 ? '' : 's'} em cluster`}
          {boundaryReady ? ' · limite municipal IBGE' : ''}
        </span>
      </div>
      <div ref={host} className="map" />
    </div>
  );
}

function Detail({item,onClose,onStatus}:{item:QueueItem;onClose:()=>void;onStatus:(s:Status)=>void}) {
  return <section className="detail" aria-label="Detalhe da ocorrência"><div className="detail-head"><div><span className={`priority-badge p${item.effective_priority}`}>P{item.effective_priority} {priorityName[item.effective_priority]}</span><h2>{categoryName[item.category]}</h2><code>{item.protocol}</code></div><button className="close" onClick={onClose} aria-label="Fechar detalhe">×</button></div>
    <div className="rule-callout"><strong>{item.ordering_reason}</strong><span>{item.hard_rule_priority > 0 ? 'Palavras de risco à vida detectadas. A regra tem precedência sobre qualquer IA.' : item.ai_rationale ?? 'Classificação por tempo e ordem de chegada.'}</span></div>
    <dl><div><dt>Recebida</dt><dd>{new Date(item.received_at).toLocaleString('pt-BR')}</dd></div><div><dt>Precisão GPS</dt><dd>{item.accuracy_m?.toFixed(0) ?? '—'} m</dd></div></dl>
    <h3>Relato</h3><p className="report">{item.description}</p>
    <a className="coordinates" href={`https://www.openstreetmap.org/?mlat=${item.latitude}&mlon=${item.longitude}#map=18/${item.latitude}/${item.longitude}`} target="_blank" rel="noreferrer">{item.latitude.toFixed(6)}, {item.longitude.toFixed(6)}</a>
    <div className="actions"><button onClick={()=>onStatus('opened')}>Abrir</button><button onClick={()=>onStatus('dispatched')}>Despachar</button><button className="resolve" onClick={()=>onStatus('resolved')}>Resolver</button></div>
  </section>;
}

function App() { const [ready,setReady]=useState(false); const [signed,setSigned]=useState(false); useEffect(()=>{supabase.auth.getSession().then(({data})=>{setSigned(!!data.session);setReady(true)}); const {data}=supabase.auth.onAuthStateChange((_e,s)=>setSigned(!!s)); return()=>data.subscription.unsubscribe();},[]); if(!ready)return <div className="boot">Abrindo sala de operações…</div>; return signed?<Operations/>:<Login/>; }
ReactDOM.createRoot(document.getElementById('root')!).render(<React.StrictMode><App /></React.StrictMode>);
