# Fontes de dados do BluAlert

Este documento registra de onde vem cada número exibido pelo aplicativo, o que é
medição, o que é previsão e o que continua indisponível. Ele é a referência para
qualquer alteração na área "Situação em Blumenau" e no mapa.

**Princípio:** uma tela vazia e correta é preferível a um painel convincente com
informação inventada. Nenhum valor é estimado pelo código.

---

## Diagnóstico: por que aparecia "Dados oficiais indisponíveis"

Duas causas independentes, ambas confirmadas em 09/09/2026.

### Causa A — cadeia TLS incompleta (bloqueava toda a consulta)

`defesacivil.blumenau.sc.gov.br` envia **apenas o certificado folha** e omite o
intermediário Sectigo:

```
$ openssl s_client -connect defesacivil.blumenau.sc.gov.br:443 \
    -servername defesacivil.blumenau.sc.gov.br
 0 s:CN = *.blumenau.sc.gov.br
   i:C = GB, O = Sectigo Limited, CN = Sectigo Public Server Authentication CA DV R36
Verify return code: 21 (unable to verify the first certificate)
```

Navegadores se recuperam sozinhos: buscam o intermediário pela extensão AIA do
certificado. **Dart e Node não fazem isso.** Node falhava com
`UNABLE_TO_VERIFY_LEAF_SIGNATURE` — inclusive com a flag `--use-system-ca` que
havia em `package.json`, que era uma tentativa anterior de correção e **não
resolvia**.

Não é interceptação de rede: o emissor é o Sectigo legítimo, não uma CA
corporativa.

**Correção aplicada:** a Edge Function `situation` fornece o intermediário junto
às raízes do sistema (`supabase/functions/_shared/sectigo.ts`). A verificação da
cadeia continua **completa** — o oposto de desligar a validação. Nunca troque
isso por `rejectUnauthorized: false` ou `--insecure`.

Quando a Prefeitura corrigir o servidor, o remendo pode ser removido: refaça o
comando acima; se a cadeia passar a trazer dois certificados, não é mais preciso.

### Causa B — URL errada

O código consultava `/c/meteorologia/aplicativo`, que é a página **"sobre o
aplicativo"**, não a de dados. As expressões regulares casavam apenas com itens
do **menu de navegação** ("Nível do Rio", "Itajaí-Açu"), sem número algum. Mesmo
com o TLS corrigido, a extração falharia.

As páginas corretas são `/d/nivel-do-rio` (situação) e
`/c/meteorologia/legenda_nivel_rio` (critérios).

---

## Fontes em uso

### 1. ANA — nível do rio (MEDIÇÃO)

| Item | Valor |
|---|---|
| URL | `https://telemetriaws1.ana.gov.br/ServiceANA.asmx/DadosHidrometeorologicos` |
| Fonte oficial | https://www.snirh.gov.br/hidrotelemetria/ |
| Estação | **83800010 — PCH Salto Jusante**, −26,9175 / −49,0661 |
| Campos | `DataHora`, `Nivel` (cm, convertido para m) |
| Frequência | Horária |
| Timeout | 15 s |
| Cache | 30 min |
| CORS | **Não** → exige proxy |
| Licença | Dado público federal (ANA). Citar a fonte. |
| Cartão | Não exige |

A estação foi escolhida por inventário (`HidroInventario`, município BLUMENAU),
não por chute: é a única fluviométrica telemétrica com dados correntes no
perímetro urbano. A estação **83800002 ("BLUMENAU (PCD)") consta do inventário
mas não devolve leituras** — está morta.

**Validação cruzada de datum:** em 09/09/2026 a ANA reportou 2,52 m às 09:00 e a
Defesa Civil publicou 2,47 m em 08/09. Diferença de 5 cm — os referenciais
coincidem, o que autoriza aplicar as cotas municipais à série da ANA.

**Se cair:** o nível publicado pelo município ainda é exibido, sem série e com
"tendência indisponível".

### 2. AlertaBlu / Defesa Civil de Blumenau — situação oficial (DECLARAÇÃO OFICIAL)

| Item | Valor |
|---|---|
| URL | `https://defesacivil.blumenau.sc.gov.br/d/nivel-do-rio` |
| Critérios | `https://defesacivil.blumenau.sc.gov.br/c/meteorologia/legenda_nivel_rio` |
| Campos | nível publicado, data de publicação, estágio do rio, estágio meteorológico por região |
| Frequência | Cerca de uma vez ao dia |
| Timeout | 15 s · Cache 30 min |
| CORS | **Não** → exige proxy |
| Cartão | Não exige |

Foram procurados API, JSON, GeoJSON, RSS e CSV no domínio antes de recorrer à
extração de HTML — **não existe endpoint equivalente**; a página é renderizada no
servidor. A extração é tolerante: campo ausente vira `null` e simplesmente não
aparece. Se a estrutura mudar a ponto de nada ser reconhecido, a função devolve
erro explícito em vez de valores inventados.

#### Cotas oficiais vigentes

Publicadas pela Defesa Civil de Blumenau (adaptado do AlertaRio):

| Estágio | Faixa |
|---|---|
| Normalidade | 0 – 3 m |
| Observação | 3 – 4 m |
| Atenção | 4 – 6 m |
| Alerta | 6 – 8 m |
| Alerta Máximo | acima de 8 m |

O aplicativo só classifica o nível **porque estes limites são publicados**. Sem
eles, nenhuma classificação seria feita.

### 3. Open-Meteo — condições e previsão (PREVISÃO DE MODELO)

| Item | Valor |
|---|---|
| URL | `https://api.open-meteo.com/v1/forecast` |
| Fonte oficial | https://open-meteo.com/ |
| Campos | `temperature_2m`, `apparent_temperature`, `relative_humidity_2m`, `precipitation`, `weather_code` (WMO 4677), `wind_speed_10m`, séries horária e diária |
| Timeout | 12 s · Cache 30 min |
| CORS | **Sim** (`*`) → consultado direto pelo Flutter |
| Licença | CC BY 4.0 · atribuição "Open-Meteo.com" |
| Limite | ~10.000 chamadas/dia na camada gratuita, sem chave e sem cartão |

**Isto é previsão, não medição.** Não existe estação meteorológica municipal
consultável por API; a interface diz isso explicitamente em cada bloco.

O consumo é mantido baixo por desenho: os 35 bairros vão em **uma única
requisição em lote** (~3 KB, 0,7 s), com cache de 30 min. O piloto fica na casa
de dezenas de chamadas por dia.

### 4. Prefeitura de Blumenau — bairros oficiais (GEODADO OFICIAL)

| Item | Valor |
|---|---|
| URL | `https://geo.blumenau.sc.gov.br/server/rest/services/Limites/Bairros/FeatureServer/0` |
| Camada | `GEO.BAIRROS`, campos `BAIRROS` e `CD_BAIRRO` |
| Projeção | EPSG:31982, reprojetada para EPSG:4326 pelo servidor (`outSR`) |
| CORS | Sim |
| Consultado em | 09/09/2026 |

Gera `lib/data/neighborhoods_data.dart` com os **35 bairros oficiais**. O nome
oficial é preservado em `officialName` (a camada armazena sem acento e em caixa
alta); `displayName` restaura a acentuação apenas para leitura.

A coordenada é o **centroide do maior anel do polígono oficial** — uma
*coordenada de referência do bairro*. Não é a sede, não é o centro exato e não é
uma estação meteorológica.

### 5. IBGE — limite municipal (GEODADO OFICIAL)

| Item | Valor |
|---|---|
| URL | `https://servicodados.ibge.gov.br/api/v3/malhas/municipios/4202404` |
| Formato | GeoJSON, qualidade máxima (~15 KB) |
| CORS | Sim (`*`) · Cache 1 dia |
| Licença | Dado público do IBGE, uso livre com citação |

Usado para desenhar o contorno de Blumenau no aplicativo e no painel. **Não se
desenha polígono aproximado:** ou o limite vem do IBGE, ou nada é desenhado.

### 6. OpenStreetMap — tiles do mapa

| Item | Valor |
|---|---|
| URL | `https://tile.openstreetmap.org/{z}/{x}/{y}.png` |
| Licença | ODbL · atribuição "© OpenStreetMap contributors" obrigatória |
| Custo | Gratuito, sem chave, sem cartão |

O painel usava `demotiles.maplibre.org`, que é um servidor de **demonstração**
da MapLibre, com mapa-múndi de baixo detalhe, sem as ruas de Blumenau e não
destinado a produção. Foi substituído.

Condições da Tile Usage Policy da OSMF cumpridas: identificação por User-Agent,
carregamento apenas da área visível (`panBuffer: 1`), sem pré-carga em massa e
navegação limitada ao município. Para trocar de provedor sem tocar no código do
mapa: `--dart-define=MAP_TILE_URL=...` no aplicativo e `VITE_MAP_TILE_URL` no
painel. A atribuição nunca é ocultada.

---

## Limitação mais importante: resolução da previsão por bairro

A grade do Open-Meteo tem cerca de 11 km. Medido em 09/09/2026, os **35 bairros
oficiais caem em apenas 8 células**:

| Célula | Bairros |
|---|---|
| −26,8893 / −49,0909 | **20** (Centro, Água Verde, Boa Vista, Bom Retiro…) |
| −26,9596 / −49,0455 | 5 (Da Glória, Garcia, Progresso, Ribeirão Fresco…) |
| −26,8893 / −49,1907 | 3 (Badenfurt, Passo Manso, Velha Central) |
| −26,8190 / −49,0366 | 2 (Fidélis, Fortaleza Alta) |
| −26,8190 / −49,1362 | 2 (Itoupava Central, Testo Salto) |
| −26,9596 / −49,1454 | 1 (Velha Grande) |
| −26,7487 / −49,0819 | 1 (Vila Itoupava) |
| −26,8893 / −48,9911 | 1 (Vorstadt) |

Exibir 35 previsões distintas produziria diferenças decimais que são **apenas
arredondamento**, e sugeriria medição por bairro. Por isso o aplicativo agrupa
por célula, usando a coordenada que a **API devolveu** — nunca a que foi pedida —
e informa isso antes dos números.

---

## Estados de disponibilidade

Tratados separadamente em `DataState`, porque significam coisas diferentes:

| Estado | Significado |
|---|---|
| `loading` | Consulta em andamento, sem valor anterior |
| `fresh` | Valor recém-obtido, dentro da validade |
| `cachedValid` | Cache ainda válido |
| `stale` | Cache vencido — exibido **só** com selo "última leitura disponível" e horário |
| `partial` | Parte das fontes respondeu |
| `offline` | Sem conexão no aparelho |
| `sourceDown` | Fonte com erro, timeout ou recusa |
| `invalidResponse` | Respondeu, mas o conteúdo não foi interpretado |
| `noDataAvailable` | Fonte no ar, sem estação ou previsão para o ponto |
| `locationDenied` | Permissão de localização necessária e não concedida |

"Normalidade" publicada pela Defesa Civil é **afirmação oficial de que não há
risco informado** — distinta de "sem dados".

**Falhas são independentes.** Uma queda no nível do rio não esconde a previsão do
tempo; cada bloco mostra o próprio estado, e o painel sinaliza quando está
parcial.

Detalhe técnico (código HTTP, exceção, stack) vai **apenas para o log**. A tela
recebe linguagem comum, horário da última tentativa, botão "Atualizar" e link
"Ver fonte oficial".

---

## Validação de plausibilidade

Valores fora de faixa são descartados antes de chegar à tela, para que sentinela
(`-9999`) ou dado corrompido não vire "nível do rio":

| Grandeza | Faixa aceita | Justificativa |
|---|---|---|
| Nível do rio | 0 – 20 m | Recorde histórico de 1984: 15,34 m |
| Temperatura | −10 – 55 °C | Folga confortável para Blumenau |
| Umidade | 0 – 100 % | Definição da grandeza |
| Precipitação | 0 – 500 mm | Janela curta |
| Vento | 0 – 250 km/h | Folga sobre vendaval severo |

---

## Tendência do rio

Calculada **somente** com medições reais, em janela de 3 h, exigindo no mínimo
3 leituras e leitura mais recente com no máximo 6 h. Tolerância de 5 cm separa
"estável" de movimento real — abaixo disso é ruído típico de régua limnimétrica.

Faltando série, o resultado é **"tendência indisponível"**, nunca "estável":
"estável" tranquilizaria sem base. A janela e o número de leituras aparecem na
tela junto do resultado.

---

## O que continua indisponível

- **Estação meteorológica municipal por API.** Não há endpoint consultável; toda
  informação de tempo é previsão de modelo.
- **Camadas de risco de deslizamento e de inundação.** Existe a camada
  `Geologia/Perigo_Risco_a_Deslizamento` no servidor da Prefeitura, mas seus
  termos de licenciamento e a vigência não foram confirmados. Permanecem
  **desligadas** (`landslide_layer_enabled`, `flood_layer_enabled` em
  `remote_config`) e identificadas como indisponíveis. Ligar sem confirmar
  licença e vigência desenharia risco não validado sobre a casa de alguém.
- **`Defesa_Civil/Cota_Enchente_Antiga1983`.** É a cota de 1983, histórica; não
  é cota vigente e não deve ser usada para decisão.
- **CEMADEN e INMET.** Avaliados: o endpoint aberto do CEMADEN não respondeu e a
  API nova da ANA (`hidrowebservice`) exige credencial (HTTP 401). Nenhum dos
  dois entrou no piloto.
- **Previsão diferenciada por bairro.** Limitada pela grade, conforme acima.

---

## Localização da ocorrência

O ponto do GPS **passa obrigatoriamente por confirmação no mapa** antes do envio
(`lib/location_picker.dart`). O motivo é operacional: sob mata, em vale ou dentro
de casa o desvio do GPS passa de 50 m com frequência em Blumenau, e um ponto
errado manda a equipe para a rua errada. Quem está no local é a única pessoa
capaz de corrigir.

Consequência registrada no dado, não escondida:

| Origem | `accuracyM` | Círculo de precisão no mapa |
|---|---|---|
| `gps` | precisão informada pelo aparelho | desenhado |
| `manuallyAdjusted` | **nulo** | **não desenhado** |

Mostrar o raio do GPS sobre um ponto escolhido à mão seria fingir uma precisão
que não existe, e a equipe usaria esse raio para planejar a busca. A origem
viaja para a central no campo `locationSource`.

O mapa é preso ao município; um ponto fora de Blumenau bloqueia a confirmação e
aponta o 199, porque a Defesa Civil municipal não atende fora do território.

Esquema local: a coluna `location_source` entrou no esquema 2 do banco da fila,
com migração incremental (`addColumn`) que preserva ocorrências já pendentes no
aparelho.

## Gráfico do nível do rio

Desenha **apenas medições reais** da estação telemétrica — nunca interpola ponto
inexistente nem preenche buraco de série. Exige no mínimo 3 leituras; abaixo
disso mostra "série insuficiente" em vez de uma linha inventada.

A escala vertical inclui a **próxima cota oficial acima do observado**, para que
a distância até ela seja visível. Um gráfico ajustado só aos dados faria uma
variação de 10 cm parecer uma cheia. As cotas aparecem tracejadas, com nome, e a
legenda traz unidade, número de leituras e o intervalo de horários.

## Configuração remota

Lida de `remote_config` pela função `remote-config` e aplicada sem republicar o
aplicativo:

| Campo | Efeito | Padrão local seguro |
|---|---|---|
| `weather_cache_seconds` | validade do cache do tempo | 1800 s |
| `hydrology_cache_seconds` | validade do cache do rio | 1800 s |
| `neighborhood_forecast_enabled` | liga/desliga previsão por bairro | ligado |
| `landslide_layer_enabled` | camada de deslizamento | **desligado** |
| `flood_layer_enabled` | camada de inundação | **desligado** |
| `maintenance_notice` / `data_notice` | avisos na tela | ausente |
| `map_tile_url` / `map_tile_attribution` | troca de provedor cartográfico | OpenStreetMap |

Todo campo cai no padrão local quando vier ausente, vazio ou fora de faixa: uma
configuração remota corrompida não pode desconfigurar o aplicativo. Cache fora
de 5 min–6 h é rejeitado, e trocar de provedor de tiles **soma** a atribuição do
OpenStreetMap em vez de substituí-la.

## Painel operacional

As ocorrências entram no mapa como **clusters** nativos do MapLibre (fonte
GeoJSON com `cluster: true`), sem biblioteca adicional. Numa enchente chegam
dezenas de registros no mesmo quarteirão e alfinetes soltos viram mancha
ilegível. O cluster guarda a **maior prioridade do grupo** (`clusterProperties`)
e usa essa cor: um grupo que contém uma P5 não pode parecer rotina. Clicar
aproxima até o cluster se abrir.

## Como atualizar a lista de bairros

A lista é gerada da fonte oficial e versionada para funcionar offline. Para
regenerar, consulte o `FeatureServer` da Prefeitura com `outSR=4326`, calcule o
centroide do maior anel e reescreva `lib/data/neighborhoods_data.dart`,
atualizando a data de consulta no cabeçalho do arquivo.
