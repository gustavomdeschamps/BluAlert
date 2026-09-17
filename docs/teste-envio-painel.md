# Teste real do envio e painel — 16/09/2026

O envio foi feito pelo formulário Flutter na sessão do usuário já autenticada
no Chrome. Foi usada a imagem de exemplo do projeto e o relato:

> TESTE ESCOLAR BLUALERT: verificacao de envio e recebimento no painel. Imagem
> de exemplo; nao e uma emergencia real e nao solicita atendimento.

A localização foi simulada no navegador nas coordenadas do SENAI Blumenau.
Isso verifica o formulário e a confirmação no mapa, mas não testa o GPS real.
As simulações de localização e tamanho de tela foram removidas ao terminar.

## Resultado

| Verificação | Resultado |
|---|---|
| UUID | `1cdc65fa-56b9-4c1e-9088-607142245e1d` |
| Protocolo | `BLU-20260916-1CDC65FA` |
| `occurrence-session` | HTTP 201 |
| Upload e `occurrence-confirm` | HTTP 201; estado recebido |
| Consulta de `operation_queue` | HTTP 200; mesmo UUID e protocolo; estado `received` |
| Foto | 471.140 bytes; upload confirmado nos metadados |
| Integridade | Tamanho e SHA-256 dos bytes do Storage iguais aos metadados |
| Repetição do mesmo UUID | HTTP 200; `alreadyReceived=true`; mesmo protocolo |
| Painel React | Protocolo, relato e foto conferidos visualmente |
| Realtime do painel | Atualização em tempo real conectada |
| Erros do navegador no painel | Nenhum erro capturado |

O painel foi configurado localmente em `operator-panel/.env` com a URL e a
chave pública do mesmo Supabase. Está em `http://127.0.0.1:5173/` enquanto o
servidor Vite estiver em execução. A entrada no painel foi feita normalmente;
nenhum token foi transferido do app para o painel.

## Limitação encontrada

O formulário aberto estava sem `TEST_LOCATION_ENABLED`. A tentativa de marcar
somente essa requisição como teste não teve efeito: o registro ficou
`is_test=false`, embora o relato esteja explicitamente identificado como teste
escolar. Esse campo não foi alterado no banco e nenhuma ação de despacho ou
resolução foi realizada.

Foi preparada a execução `./run-blualert.bat --test` e a configuração VS Code
**BluAlert: Chrome modo de teste**, que habilitam o modo de teste já existente
no código. Os próximos envios devem ser verificados com essa configuração;
o envio documentado acima ocorreu com o app que já estava aberto.

O teste não verificou GPS em aparelho Android, retomada offline, atendimento
humano, papel de cada conta operacional ou funcionamento do serviço opcional Ollama.

Captura final: `tmp/operator-panel-test-final.png`.
