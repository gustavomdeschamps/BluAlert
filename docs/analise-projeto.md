# Revisão do BluAlert — 16/09/2026

## Correção posterior do acesso e verificação de duplicados

A mensagem da captura de tela não veio do Supabase: o aplicativo recusou entrar
antes de fazer uma requisição, porque `.dart-defines.json` estava ausente nesta cópia.
Ter uma conta cadastrada não configura automaticamente o aplicativo.

Após o usuário fornecer a chave pública, `.dart-defines.json` foi configurado
para o projeto vinculado `mnpdgswaujmryhykyyaf`. A consulta real a
`/auth/v1/settings` confirmou que a chave é aceita, o login por e-mail está
habilitado e os cadastros estão ativos. A Edge Function `remote-config` também
respondeu com a configuração de piloto. Nenhuma senha foi solicitada ou usada;
o login da conta individual precisa ser feito pelo usuário no app reiniciado.

Por solicitação do usuário, `run-blualert.bat` prepara as dependências e abre
o Chrome sem perguntas. Se faltar configuração, o login fica indisponível.
O configurador `configure-supabase.ps1` é executado separadamente para pedir
a URL e a chave pública do projeto existente. O arquivo é
salvo sem BOM e não substitui um arquivo existente. A validação recusa exemplos,
chaves secret/service_role, tokens de usuário e chaves anon de outro projeto.
Ela valida o formato, não comprova que uma chave está ativa no servidor.
O F5 com Supabase verifica esse arquivo antes de executar e aparece primeiro
na lista de configurações. O script avisa quando abre sem configuração de backend.

URLs e chaves são normalizadas no cliente. No login, a senha só precisa estar
preenchida: o Supabase verifica as credenciais de contas existentes. A regra
de oito caracteres permanece no cadastro de novas contas.

Foram comparados por SHA-256 os 150 arquivos presentes antes desta correção,
excluindo cache, dependências, builds e temporários. Não houve código-fonte
duplicado. Os conteúdos iguais são recursos exigidos em caminhos separados:

- `android/app/src/debug/AndroidManifest.xml` e `profile/AndroidManifest.xml`;
- ícones web de 192 e 512 pixels nas variantes comuns e maskable;
- o ícone Android xxxhdpi tem os mesmos bytes dos ícones web de 192 pixels.

Esses recursos foram preservados: apagá-los pode quebrar uma variante da build.
As pastas `.dart_tool`, `.dart-tool` e `.pub-cache` são arquivos/cache de ferramentas,
não cópias do código do aplicativo.

Validação desta correção: análise Flutter sem problemas, 101 testes Flutter
passaram e cinco testes do configurador passaram. O login remoto permanece
pendente da entrada do usuário no aplicativo. A conexão com a chave pública
fornecida foi validada no servidor real.

## Estrutura e avaliação

O aplicativo principal usa Flutter/Dart e tem versões Android e web. O painel
de operações usa React, TypeScript e Vite. O Supabase fornece autenticação,
banco de dados, Storage privado e Edge Functions. A triagem opcional usa Ollama.
O servidor Node da raiz serve a versão web compilada.

A fila local, as mensagens que distinguem armazenamento de recebimento e os
testes de fontes indisponíveis são boas bases para a apresentação escolar.
Isso ainda não comprova funcionamento em uma operação real da Defesa Civil.

## Correções realizadas

- Instalação das dependências Flutter e do painel.
- Atualização de MapLibre GL para 6.10.0 e adaptação do import. A auditoria npm
  identificou uma vulnerabilidade crítica de XSS na versão anterior; a instalação
  da versão corrigida informou zero vulnerabilidades.
- Preservação do refresh token diante de falhas de rede ou erros temporários
  do servidor. A sessão só é apagada quando a renovação é recusada por autenticação.
- Bloqueio de nova tentativa manual para ocorrência já recebida.
- Servidor estático: URL malformada passa a devolver 400; bloqueio de caminhos
  fora da pasta da build; tratamento de erro na leitura do arquivo.
- Edge Functions: recusa de métodos diferentes de POST, validação de tamanho
  inteiro das mídias, verificação de erro ao gravar metadados e bloqueio de uso
  de um ID de mídia pertencente a outra ocorrência.
- Confirmação de upload: comparação SHA-256 dos bytes armazenados com o hash
  informado, além da checagem de tamanho. Isso aumenta a leitura de Storage.
- Serviço de triagem: limite de tempo para Ollama, rejeição de prioridade inválida,
  recuperação sem consultas simultâneas e tratamento de erro no callback Realtime.
- Configurações F5 e extensões recomendadas no VS Code. Na revisão inicial o
  script permitia abrir sem backend; a correção posterior passou a exigir configuração.

## Supabase: correção preparada, ainda não aplicada

As funções SQL de alteração de status, prioridade e sugestão de IA verificavam
`actor_role NOT IN (...)`. Em SQL, quando o perfil não existe, essa expressão é
NULL e o `IF` não entra: a função continua. As funções também herdavam a permissão
de execução de PUBLIC. Em conjunto, isso permite contornar a autorização.

O arquivo `docs/supabase-security-fix.sql` redefine essas três funções para
recusar chamadas sem usuário ou perfil e remove a execução pública/anônima.
É um script de correção para o SQL Editor, não uma migration aplicada.
As migrations históricas foram preservadas. O script precisa ser conferido
contra a versão efetivamente publicada antes de executar e incorporado depois
à história de migrations com a CLI do Supabase.

Teste remoto necessário: anon e usuário sem perfil devem ser recusados;
reporter não pode alterar ocorrência real; operator/supervisor podem operar;
reporter pode classificar apenas sua própria ocorrência marcada como teste.

As alterações em `occurrence-session` e `occurrence-confirm` também precisam
ser publicadas para produzir efeito no servidor. Esta sessão não tem conexão
autenticada ao projeto Supabase; nenhum dado remoto foi alterado ou inspecionado.

## Validações

- `flutter analyze --no-pub`: sem problemas.
- `flutter test --no-pub`: 100 testes existentes passaram na primeira verificação.
- Verificação final `flutter analyze --no-pub lib test`: sem problemas.
- `flutter test --no-pub test/queue_test.dart`: 18 testes passaram, incluindo
  o novo teste que impede reabrir uma ocorrência recebida.
- `flutter build web --release --pwa-strategy=none --no-pub`: compilou.
- `npm run build` no painel após atualização do mapa: compilou.
- `npm test` na raiz: três testes de segurança do servidor passaram.
- `node --test supabase/functions/security.test.cjs`: dois testes com backend
  simulado passaram, verificando métodos HTTP e recusa de hash incorreto.
  Requer `npm ci` em `operator-panel` para usar o compilador TypeScript.
- Instalação das dependências do serviço de triagem: zero vulnerabilidades
  informadas pelo npm. O serviço não foi iniciado sem uma conta de operação.
- Verificação sintática Node do servidor e serviço de triagem.

A build Flutter emitiu um aviso sobre fontes Cupertino, sem impedir a compilação.
O painel emitiu aviso de bundle grande; isso pode prejudicar o carregamento em
conexão lenta. Não foi executado teste visual no navegador nem teste de campo Android.

## Pendências que dependem do ambiente

1. Preencher `.dart-defines.json` com a URL e a chave pública do Supabase existente.
2. Conferir migrations, funções publicadas, RLS, contas e confirmação de e-mail
   no projeto remoto; aplicar e verificar a correção SQL preparada.
3. Testar cadastro/login e ocorrência com foto até aparecer o protocolo no painel;
   repetir em modo avião e com localização negada, usando ocorrências de teste.
4. No Android, configurar assinatura de release. Hoje o projeto usa chave debug.
5. No navegador, a fila fica em memória: fechar a aba perde ocorrências pendentes.
6. A pasta recebida não contém `.git`; não foi possível comparar com o repositório
   remoto nem criar um histórico das alterações nesta cópia.

Não adicione chave service_role ao aplicativo ou ao painel. Não é necessário
enviar senha ou chave privada para configurar a execução local.

## Executar

No VS Code, instale Dart e Flutter e execute `./run-blualert.bat` no terminal.
Configure separadamente pelo script `configure-supabase.ps1`. Nas próximas execuções,
a configuração existente é reutilizada. Depois também é possível escolher
**BluAlert: Chrome com Supabase** em Executar e Depurar e pressionar F5.

No terminal da raiz também funciona `./run-blualert.bat`.
Para servir a build já gerada: `npm start` e abra `http://127.0.0.1:3000`.
A build gerada nesta análise está sem credenciais Supabase: refaça-a com
`--dart-define-from-file=.dart-defines.json` depois de configurar o projeto.

O painel exige seu próprio `operator-panel/.env`, baseado no `.env.example`.
A configuração Flutter não é reutilizada automaticamente pelo painel.

Referências usadas: [sessões Supabase](https://supabase.com/docs/guides/auth/sessions)
e [aviso de segurança MapLibre](https://github.com/advisories/GHSA-jrc7-96c5-q579).
