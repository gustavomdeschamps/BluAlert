# BluAlert

Protótipo escolar de orientação e registro de ocorrências em Blumenau. O BluAlert não é um aplicativo oficial da Defesa Civil. O projeto ainda não dispõe de uma equipe de atendimento para os registros enviados.

> **VERSÃO PILOTO.** O canal digital está em teste e não substitui a central de
> emergência. Nenhuma equipe é acionada automaticamente pelo aplicativo. Em
> risco imediato, ligue **199** (Defesa Civil) ou **193** (Bombeiros).

## O que já funciona

- abertura com animação da marca, respeitando "reduzir movimento";
- cadastro por e-mail e senha, com confirmação por e-mail, reenvio com contagem
  regressiva e restauração de sessão em aberturas seguintes;
- registro de ocorrência em fila **offline-first**: a ocorrência é gravada no
  aparelho e enviada sozinha quando houver conexão, com recuo exponencial e
  limite de tentativas;
- foto obrigatória comprimida para caber em 800 KB **sem descer abaixo do piso
  de legibilidade** (1024 px, qualidade 62); vídeo opcional de até 20 segundos e
  10 MB, recusado antes de gastar dados se ultrapassar o limite;
- upload por URL assinada para Storage privado, com idempotência por UUID
  gerado no cliente — reenviar não duplica a ocorrência;
- estados de envio distintos e honestos: *salvo no aparelho*, *aguardando
  conexão*, *enviando mídia*, *aguardando confirmação*, *registrado no sistema*
  e *precisa da sua ação*. **Nenhum estado local é chamado de "enviado"**;
- mapa real da região, mediante autorização explícita de localização;
- leitura da situação publicada pelo AlertaBlu, sem reutilizar valores antigos
  quando a fonte estiver indisponível;
- atalhos reais para Defesa Civil (199), Bombeiros (193) e SAMU (192), com aviso
  visível se o discador não abrir;
- guias de prevenção disponíveis no aparelho.

### Limites conhecidos

- **Android é o destino previsto para uso em campo.** No navegador, a fila e as evidências
  ficam em memória: fechar a aba perde o que ainda não foi confirmado. A
  interface avisa isso na revisão do envio.
- A promoção para `operator` e `supervisor` é manual, pelo SQL Editor.
- Para gerar Android de distribuição será necessária uma chave de assinatura
  própria em `android/key.properties`; veja `android/key.properties.example`.
- O piloto web aceita registros para teste, sem plantão ou resposta garantida.
  Para pedir exclusão de dados, use o contato em `web/privacy.html`.

## Executar

### Abrir no VS Code

Abra **Arquivo → Abrir Pasta** e selecione a pasta `BluAlert`. Instale as
extensões recomendadas **Dart** e **Flutter**. Execute `./run-blualert.bat` no
terminal primeiro. O script prepara as dependências e abre o Chrome sem pedir
dados no terminal. Quando `.dart-defines.json` existir, ele usa essa configuração;
sem o arquivo, as telas abrem, mas login e envio ficam indisponíveis.
Para configurar separadamente, execute
`powershell -NoProfile -ExecutionPolicy Bypass -File ./configure-supabase.ps1`.
Depois, em **Executar e Depurar**, escolha **BluAlert: Chrome com Supabase** e
pressione **F5**.

Para conectar ao projeto Supabase já existente, copie `.dart-defines.json.example`
para `.dart-defines.json` e preencha `SUPABASE_URL` e `SUPABASE_ANON_KEY` com a URL
e a chave pública do seu projeto. Depois escolha **BluAlert: Chrome com Supabase**.
Sem esses valores, cadastro e envio de ocorrências ficam indisponíveis.

A revisão e as pendências de implantação estão em `docs/analise-projeto.md`.

No Windows, o caminho mais confiável é:

```powershell
.\run-blualert.bat
```

O script usa o cache privado `.pub-cache` dentro do projeto e impede que a limpeza automática do computador da escola remova pacotes durante a compilação. No VS Code, a mesma execução está disponível em **Terminal → Run Task → BluAlert: executar no Chrome**.

Para abrir no navegador, selecione Chrome ou Edge quando o Flutter solicitar um dispositivo. Para Android, use um aparelho conectado ou um emulador.

O endereço mostrado no terminal como `Dart VM Service` pertence apenas ao
depurador. Não abra esse link na aba interna do VS Code: o BluAlert é executado
na janela do Chrome aberta automaticamente pelo comando.

### Versão web

A publicação web usa GitHub Actions e GitHub Pages. O fluxo está em
`.github/workflows/web-pages.yml`; a URL prevista é
`https://gustavomdeschamps.github.io/BluAlert/`. O aviso de privacidade fica
em `/BluAlert/privacy.html`. Em **Settings → Pages**, escolha **GitHub Actions**
como origem da publicação.

No Supabase hospedado, abra **Authentication → URL Configuration** e defina
**Site URL** como `https://gustavomdeschamps.github.io/BluAlert/`. Esse é o
destino padrão dos links de confirmação por e-mail quando o cadastro não envia
um redirecionamento específico; mantenha URLs locais adicionais somente se
precisar testar o aplicativo no computador.

```bash
flutter build web --release --pwa-strategy=none --dart-define-from-file=.dart-defines.json
npm start
```

Depois, abra `http://127.0.0.1:3000`. O `server/` é **apenas** um servidor de
arquivos estáticos: não consulta fontes oficiais nem recebe ocorrências.

### Dados oficiais

A leitura das fontes oficiais vive na Edge Function `situation`, que serve
Android e web pelo mesmo caminho. Ela existe porque nem a ANA nem a Defesa Civil
enviam cabeçalho de CORS, e porque o servidor da Prefeitura entrega uma **cadeia
TLS incompleta** que Dart e Node não conseguem completar sozinhos — era esta a
causa do antigo "Dados oficiais indisponíveis".

| Dado | Fonte | Natureza |
|---|---|---|
| Nível do rio | ANA, estação 83800010 | Medição horária |
| Estágio e avisos | Defesa Civil de Blumenau | Declaração oficial |
| Tempo e previsão | Open-Meteo | Previsão de modelo (~11 km) |
| Bairros | Prefeitura (ArcGIS) | Geodado oficial |
| Limite municipal | IBGE | Geodado oficial |
| Mapa | OpenStreetMap | Atribuição obrigatória |

Detalhes de licença, limites, cache, comportamento de falha e o que continua
indisponível estão em **`docs/fontes-de-dados.md`**.

Informe somente a URL pública e a chave `anon` do projeto ao executar. A chave `service_role` nunca entra no aplicativo:

```bash
flutter run --dart-define=SUPABASE_URL=https://SEU_PROJECT_REF.supabase.co --dart-define=SUPABASE_ANON_KEY=SUA_CHAVE_ANON
```

## Painel de operações

O app usa a localização autorizada pelo aparelho para mostrar a posição no mapa.
Cada ocorrência exige uma captura atual do GPS e confirmação do ponto no mapa;
um endereço salvo no cadastro não substitui a localização da ocorrência.

O painel de alta densidade está em `operator-panel/`. Copie `.env.example` para `.env`, preencha a URL e a chave pública do Supabase e execute:

```bash
cd operator-panel
npm install
npm run dev
```

Para gerar os arquivos destinados ao Cloudflare Pages, use `npm run build`. O diretório de saída é `operator-panel/dist`.

## Triagem assistida local

O serviço opcional em `ai-triage/` roda no notebook da operação com Ollama. Ele sugere prioridade e justificativa; não possui função capaz de fechar ou ocultar ocorrências. Copie `.env.example` para `.env`, use uma conta com papel `operator` ou `supervisor` e execute `npm install` seguido de `npm start`.

No Android, o perfil e os tokens de sessão ficam no cofre seguro do sistema
(`flutter_secure_storage`). No navegador, onde não existe cofre equivalente, eles
ficam no armazenamento local — mais um motivo para o piloto em campo usar o
aplicativo no celular. A senha nunca é gravada. O cadastro não solicita GPS.
A localização é solicitada ao abrir o mapa ou confirmar o local de uma ocorrência.

## Validação

```powershell
flutter pub get
dart run build_runner build      # código gerado do drift (fila local)
flutter analyze
flutter test
flutter build web --release --pwa-strategy=none
```

Roteiro manual mínimo antes de liberar uma versão:

1. cadastrar, confirmar o e-mail e entrar; fechar e reabrir o aplicativo — deve
   entrar direto, sem pedir a senha;
2. **no Android, ativar o modo avião**, registrar uma ocorrência com foto e enviar — precisa
   ficar em *aguardando conexão*, nunca em "enviado";
3. desligar o modo avião — a ocorrência deve sair sozinha e só então exibir
   *registrado no sistema*, com protocolo;
4. repetir o envio da mesma ocorrência — não pode duplicar no painel;
5. negar a permissão de localização — precisa aparecer instrução acionável, não
   uma tela travada;
6. tocar em **199** — o discador precisa abrir; se não abrir, o número tem de
   aparecer para digitação manual.

## Estrutura

- `lib/account_flow.dart` — abertura, cadastro, acesso e recuperação de perfil;
- `lib/emergency.dart` — configuração do piloto, aviso de VERSÃO PILOTO e
  ligações de emergência;
- `lib/queue/` — fila offline: modelos, banco SQLite (drift), armazenamento das
  evidências, compressão e o motor de envio com recuo exponencial;
- `lib/occurrence_flow.dart` — formulário, revisão e acompanhamento do estado
  real de cada envio;
- `lib/main.dart` — navegação, início, mapa, emergência e orientações;
- `supabase/` — migrations, políticas de RLS e Edge Functions;
- `operator-panel/` — painel de operações;
- `server/` — ponte de leitura da fonte oficial e servidor estático da build web.
  **Não recebe ocorrências**: elas vão direto ao Supabase, autenticadas.
