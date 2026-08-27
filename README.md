# BluAlert

Aplicativo móvel de alertas e orientação da Defesa Civil para Blumenau. O projeto prioriza decisões rápidas em situações de risco e mantém informações essenciais disponíveis mesmo sem internet, com uma experiência preparada para futura comunicação via LoRa.

## O que já funciona

- abertura única com animação da nova marca, rio e identidade própria de Blumenau;
- cadastro e acesso na mesma tela, com nome, telefone, localização e PIN;
- acesso protegido por PIN, com dados sensíveis no armazenamento seguro do Android;
- registro de ocorrência com foto, vídeo de até 30 segundos, descrição e GPS;
- envio real para o servidor BluAlert configurado, com identificador e arquivos persistidos;
- mapa real da região atual, mediante autorização explícita de localização;
- leitura da situação oficial publicada pelo AlertaBlu, sem inventar dados quando a fonte estiver indisponível;
- atalhos reais para Defesa Civil (199), Bombeiros (193) e SAMU (192);
- guias de prevenção disponíveis no aparelho;
- layout responsivo para Android e web, com identidade visual própria do BluAlert.

## Executar

```bash
flutter pub get
flutter run
```

Para abrir no navegador, selecione Chrome ou Edge quando o Flutter solicitar um dispositivo. Para Android, use um aparelho conectado ou um emulador.

### Versão web com dados oficiais

O navegador não permite consultar diretamente outro domínio. Por isso, a versão web inclui um servidor local que repassa somente a situação publicada pelo AlertaBlu:

```bash
flutter build web --release --pwa-strategy=none
npm start
```

Depois, abra `http://127.0.0.1:3000`. Se o AlertaBlu estiver fora do ar, o aplicativo informa indisponibilidade e não reutiliza valores antigos.

As ocorrências enviadas na versão local são recebidas em `server/data/occurrences`. Esse destino é o servidor de demonstração do BluAlert; ele não deve ser apresentado como canal oficial da Prefeitura até que a Defesa Civil forneça e autorize a integração de produção.

No Android, informe o endereço do servidor ao executar ou compilar:

```bash
flutter run --dart-define=BLUALERT_API_BASE=https://endereco-do-servidor
```

Na versão web, o perfil fica guardado no armazenamento local do navegador. No Android, o perfil e o PIN usam o cofre seguro do sistema. A localização só é solicitada durante o cadastro ou quando o usuário pede para atualizar o mapa.

## Estrutura

`lib/account_flow.dart` contém abertura, cadastro e acesso; `lib/main.dart` reúne painel, mapa, contatos e orientações. Os arquivos em `android/` geram o APK, `web/` contém a versão instalável no navegador e `server/` fornece a ponte de leitura para a fonte oficial na versão web.
