# Migração do backend sem desligar o BluAlert

O site da Vercel continua publicado e o Supabase permanece como backend ativo até
que o novo caminho de cadastro, envio e painel passe por testes de ponta a ponta.
Esta migração elimina a regra de pausa por **inatividade** do Supabase Free;
nenhum serviço gratuito promete disponibilidade contínua nem capacidade
ilimitada. Quando a cota gratuita acabar, novas operações poderão falhar.

## Destino escolhido

- Firebase Authentication no plano Spark para contas por e-mail e senha.
- Cloud Firestore no plano Spark para perfis, ocorrências, histórico e
  configuração operacional. Acesso direto do cliente aos dados operacionais
  negado; as rotas autenticadas da Vercel verificam o token e aplicam os papéis.
- Vercel Blob **privado** no plano Hobby para fotos e vídeos. Nunca publicar
  evidências por URL pública; as rotas do painel autorizam cada leitura.
- Vercel Functions para cadastro validado, sessão e confirmação da ocorrência,
  consulta e ações do painel e leitura das fontes oficiais.

O Firebase Storage não faz parte desta opção: desde fevereiro de 2026 ele
exige o plano Blaze, com conta de faturamento, mesmo quando o uso se mantém na
faixa sem cobrança. O Vercel Blob Hobby inclui uma cota gratuita, mas pode
interromper operações quando ela for excedida. Antes de publicar, verificar o
consumo previsto de mídia e definir um limite visível no aplicativo.

## Estado da origem em 16/10/2026

| Item | Quantidade |
|---|---:|
| Contas e perfis | 6 e 6 |
| Ocorrências | 5 |
| Registros de mídia e objetos existentes | 5 e 4 |
| Tamanho dos 4 objetos existentes | cerca de 1,35 MiB |
| Histórico de status | 6 |

Todas as contas têm perfil e todas as ocorrências têm perfil de autor. Um
registro de foto de uma ocorrência **de teste e resolvida** não tem objeto no
Storage. Na cópia, marcar essa evidência como ausente; nunca inventar a foto
nem contar o registro como arquivo transferido. Execute
`migration/source_audit.sql` novamente imediatamente antes do corte.

As seis senhas usam hash bcrypt (`$2a$`). O Firebase Admin SDK aceita importação
de usuários com bcrypt; o importador deverá preservar UID, e-mail, estado de
verificação e hash em memória, sem gravá-lo em log ou no repositório. Sessões
atuais do Supabase não migram: as pessoas entram outra vez com a mesma senha.

## Recursos preparados

Em 16/10/2026 foi criado o Blob privado `blualert-evidence` na região `gru1`
e vinculado ao projeto Vercel `blualert` nos ambientes de produção, prévia e
desenvolvimento. A conexão usa OIDC, sem token permanente gravado no
repositório. Nenhum arquivo foi copiado e a versão pública ainda usa Supabase.

O endpoint `/api/situation` da Vercel foi implantado em
`https://blualert.vercel.app` e validado com dados reais da ANA e da
publicação municipal. O app passou a consultá-lo primeiro, com a função do
Supabase como fallback temporário. App e painel responderam por HTTP 200 no
endereço público. Cadastro, ocorrências, perfis, configuração remota e painel
continuam usando Supabase; por isso a migração **não está concluída**.

O plugin Firebase está instalado no Codex, mas nesta sessão suas ferramentas
MCP não foram disponibilizadas e `firebase projects:list` respondeu
`Failed to authenticate`. A criação do projeto e a transferência de dados
dependem de uma autorização da conta Google que ainda não chegou à CLI.

## Critérios para mudar o link público

1. Criar o projeto Firebase e habilitar e-mail/senha e Firestore. O Blob privado
   já foi conectado; guardar as demais credenciais apenas nos segredos da
   Vercel ou em arquivo local ignorado pelo Git.
2. Implantar a nova API e testar cadastro, senha fraca recusada, login,
   restauração de sessão, perfil, regras de acesso e erro de rede.
3. Testar envio real com foto e vídeo, repetição do mesmo UUID, conferência de
   tamanho e SHA-256, protocolo só após confirmação, fila offline e limites.
4. Testar o painel com conta administradora e verificar que uma conta comum
   não consegue listar ocorrências nem obter mídias.
5. Copiar contas, perfis, dados, 4 objetos de mídia existentes e histórico;
   comparar contagens e amostras sem expor dados pessoais em logs.
6. Congelar novos envios durante o corte, copiar alterações finais, trocar a
   configuração do app e painel e publicar a nova versão. Manter o Supabase
   íntegro para retorno até que o novo caminho esteja estável.

O corte não deve ocorrer se a conta Firebase ou a Vercel não estiver acessível,
se a mídia privada não estiver configurada ou se qualquer teste acima falhar.
