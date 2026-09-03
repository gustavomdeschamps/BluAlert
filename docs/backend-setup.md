# Backend BluAlert — implantação do piloto

O backend foi desenhado para o plano gratuito do Supabase. Não informe cartão: se a criação do projeto exigir uma forma de pagamento, interrompa a configuração.

## Pré-requisitos

1. Crie um projeto Free no Supabase.
2. Guarde localmente a URL do projeto e a chave `anon`. A chave `service_role` nunca entra no Flutter, no painel ou no Git.
3. Instale a CLI do Supabase somente quando for realizar a implantação.

## Banco e funções

Na raiz do projeto:

```powershell
supabase login
supabase link --project-ref SEU_PROJECT_REF
supabase db push
supabase functions deploy occurrence-session
supabase functions deploy occurrence-confirm
supabase functions deploy remote-config --no-verify-jwt
supabase functions deploy escalate-queue --no-verify-jwt
```

## Conta inicial de operação

Usuários comuns começam com `reporter`. A promoção para `operator` ou `supervisor` deve ser feita manualmente no SQL Editor durante o piloto, depois de confirmar a identidade da pessoa:

```sql
update public.profiles set role = 'supervisor' where id = 'UUID_CONFIRMADO';
```

Nunca exponha uma tela pública capaz de promover funções.

Configure `CRON_SECRET` com um valor aleatório e agende `escalate-queue` a cada minuto pelo Supabase Cron. O segredo deve ser enviado no cabeçalho `x-cron-secret`. A função somente recalcula a prioridade de ocorrências ainda não abertas.

## Princípio de confirmação

O aplicativo só pode mostrar “Ocorrência recebida” depois que `occurrence-confirm` verificar os objetos e alterar o estado para `received`. Ter enviado os bytes ao Storage não é confirmação de recebimento.

## Segurança operacional

- Mantenha `pilot_mode=true` e `human_receiver_confirmed=false` até existir uma equipe formalmente responsável.
- Faça exportação criptografada diária do PostgreSQL.
- Teste mensalmente restauração, indisponibilidade do Supabase e funcionamento do 199.
- Monitore storage e tráfego aos atingir 70%, 85% e 95%.
