# BluAlert

Aplicativo móvel de alertas e orientação da Defesa Civil para Blumenau. O projeto prioriza decisões rápidas em situações de risco e mantém informações essenciais disponíveis mesmo sem internet, com uma experiência preparada para futura comunicação via LoRa.

## O que já funciona

- abertura única com animação da nova marca, rio e identidade própria de Blumenau;
- cadastro e acesso na mesma tela, com nome, telefone, localização e PIN;
- acesso protegido por PIN, com dados sensíveis no armazenamento seguro do Android;
- registro de ocorrência com foto obrigatória de até 800 KB, vídeo opcional de até 20 segundos e 10 MB, descrição e GPS;
- upload direto e autenticado para o Storage, com idempotência e confirmação final do backend;
- mapa real da região atual, mediante autorização explícita de localização;
- leitura da situação oficial publicada pelo AlertaBlu, sem inventar dados quando a fonte estiver indisponível;
- atalhos reais para Defesa Civil (199), Bombeiros (193) e SAMU (192);
- guias de prevenção disponíveis no aparelho;
- layout responsivo para Android e web, com identidade visual própria do BluAlert.

## Executar

No Windows, o caminho mais confiável é:

```powershell
.\run-blualert.bat
```

O script usa o cache privado `.pub-cache` dentro do projeto e impede que a limpeza automática do computador da escola remova pacotes durante a compilação. No VS Code, a mesma execução está disponível em **Terminal → Run Task → BluAlert: executar no Chrome**.

Para abrir no navegador, selecione Chrome ou Edge quando o Flutter solicitar um dispositivo. Para Android, use um aparelho conectado ou um emulador.

O endereço mostrado no terminal como `Dart VM Service` pertence apenas ao
depurador. Não abra esse link na aba interna do VS Code: o BluAlert é executado
na janela do Chrome aberta automaticamente pelo comando.

### Versão web com dados oficiais

O navegador não permite consultar diretamente outro domínio. Por isso, a versão web inclui um servidor local que repassa somente a situação publicada pelo AlertaBlu:

```bash
flutter build web --release --pwa-strategy=none
npm start
```

Depois, abra `http://127.0.0.1:3000`. Se o AlertaBlu estiver fora do ar, o aplicativo informa indisponibilidade e não reutiliza valores antigos.

O servidor local permanece apenas como ponte para a situação oficial do AlertaBlu na versão web. Ocorrências usam o backend Supabase descrito em `docs/backend-setup.md`.

Informe somente a URL pública e a chave `anon` do projeto ao executar. A chave `service_role` nunca entra no aplicativo:

```bash
flutter run --dart-define=SUPABASE_URL=https://SEU_PROJECT_REF.supabase.co --dart-define=SUPABASE_ANON_KEY=SUA_CHAVE_ANON
```

## Painel de operações

O painel de alta densidade está em `operator-panel/`. Copie `.env.example` para `.env`, preencha a URL e a chave pública do Supabase e execute:

```bash
cd operator-panel
npm install
npm run dev
```

Para gerar os arquivos destinados ao Cloudflare Pages, use `npm run build`. O diretório de saída é `operator-panel/dist`.

## Triagem assistida local

O serviço opcional em `ai-triage/` roda no notebook da operação com Ollama. Ele sugere prioridade e justificativa; não possui função capaz de fechar ou ocultar ocorrências. Copie `.env.example` para `.env`, use uma conta com papel `operator` ou `supervisor` e execute `npm install` seguido de `npm start`.

Na versão web, o perfil fica guardado no armazenamento local do navegador. No Android, o perfil e o PIN usam o cofre seguro do sistema. A localização só é solicitada durante o cadastro ou quando o usuário pede para atualizar o mapa.

## Estrutura

`lib/account_flow.dart` contém abertura, cadastro e acesso; `lib/main.dart` reúne painel, mapa, contatos e orientações. Os arquivos em `android/` geram o APK, `web/` contém a versão instalável no navegador e `server/` fornece a ponte de leitura para a fonte oficial na versão web.
