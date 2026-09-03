import 'dotenv/config';
import { createClient } from '@supabase/supabase-js';

const required = ['SUPABASE_URL', 'SUPABASE_ANON_KEY', 'OPERATOR_EMAIL', 'OPERATOR_PASSWORD'];
for (const key of required) if (!process.env[key]) throw new Error(`Configuração ausente: ${key}`);

const model = process.env.OLLAMA_MODEL || 'qwen2.5:3b';
const ollamaUrl = process.env.OLLAMA_URL || 'http://127.0.0.1:11434';
const supabase = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_ANON_KEY, {
  auth: { persistSession: false, autoRefreshToken: true },
});
const processing = new Set();

async function suggest(item) {
  if (processing.has(item.id) || item.status !== 'received') return;
  processing.add(item.id);
  try {
    const response = await fetch(`${ollamaUrl}/api/chat`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        model,
        stream: false,
        format: 'json',
        options: { temperature: 0.1, num_predict: 220 },
        messages: [{ role: 'system', content: [
          'Você auxilia a triagem da Defesa Civil de Blumenau.',
          'Nunca ordene fechar, descartar, ocultar ou ignorar uma ocorrência.',
          'Retorne somente JSON: {"priority":1..5,"rationale":"frase objetiva em português"}.',
          'Considere risco humano, velocidade de agravamento, alcance e infraestrutura crítica.',
          'Não invente fatos ausentes. Declare incerteza na justificativa.'
        ].join(' ') }, { role: 'user', content: JSON.stringify({
          category: item.category,
          description: item.description,
          hardRulePriority: item.hard_rule_priority,
          minutesWaiting: Math.floor((Date.now() - new Date(item.received_at).getTime()) / 60000),
        }) }],
      }),
    });
    if (!response.ok) throw new Error(`Ollama indisponível (${response.status})`);
    const answer = await response.json();
    const parsed = JSON.parse(answer.message.content);
    const priority = Math.max(1, Math.min(5, Number(parsed.priority) || 1));
    const rationale = String(parsed.rationale || '').trim();
    if (rationale.length < 10) throw new Error('Justificativa insuficiente');
    const { error } = await supabase.rpc('submit_ai_suggestion', {
      target_occurrence: item.id,
      priority,
      explanation: rationale,
      model_name: model,
      model_release: answer.created_at || null,
    });
    if (error) throw error;
    console.log(`[triagem] ${item.protocol}: P${priority} — ${rationale}`);
  } catch (error) {
    console.error(`[triagem indisponível] ${item.protocol}: ${error.message}`);
  } finally {
    processing.delete(item.id);
  }
}

async function catchUp() {
  const { data, error } = await supabase
    .from('operation_queue')
    .select('*')
    .eq('status', 'received')
    .is('ai_rationale', null)
    .limit(25);
  if (error) throw error;
  for (const item of data) await suggest(item);
}

const { error: loginError } = await supabase.auth.signInWithPassword({
  email: process.env.OPERATOR_EMAIL,
  password: process.env.OPERATOR_PASSWORD,
});
if (loginError) throw new Error(`Conta operacional recusada: ${loginError.message}`);
await catchUp();

supabase.channel('local-ai-triage')
  .on('postgres_changes', { event: '*', schema: 'public', table: 'occurrences' }, catchUp)
  .subscribe(status => console.log(`[conexão] ${status}`));

setInterval(() => catchUp().catch(error => console.error('[recuperação]', error.message)), 5 * 60 * 1000);
console.log(`Assistente BluAlert ativo com ${model}. Regras duras permanecem acima das sugestões.`);
