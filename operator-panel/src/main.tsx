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

function Map({items,selected,onSelect}:{items:QueueItem[];selected:string|null;onSelect:(id:string)=>void}) {
  const host = useRef<HTMLDivElement>(null); const map = useRef<maplibregl.Map | null>(null); const markers = useRef<maplibregl.Marker[]>([]);
  useEffect(() => { if (!host.current || map.current) return; map.current = new maplibregl.Map({container:host.current, center:[-49.0661,-26.9194], zoom:12, style:'https://demotiles.maplibre.org/style.json'}); map.current.addControl(new maplibregl.NavigationControl({showCompass:false}), 'bottom-left'); return () => map.current?.remove(); }, []);
  useEffect(() => { markers.current.forEach(marker => marker.remove()); markers.current = items.map(item => { const el=document.createElement('button'); el.className=`map-marker p${item.effective_priority}${selected===item.id?' active':''}`; el.textContent=String(item.effective_priority); el.setAttribute('aria-label',`${categoryName[item.category]}, prioridade ${item.effective_priority}`); el.onclick=()=>onSelect(item.id); return new maplibregl.Marker({element:el}).setLngLat([item.longitude,item.latitude]).addTo(map.current!); }); }, [items,selected]);
  return <div className="map-wrap"><div className="map-label"><strong>Mapa operacional</strong><span>Blumenau e região do piloto</span></div><div ref={host} className="map" /></div>;
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
