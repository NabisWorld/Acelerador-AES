# Relatório — Semana 5

## 1. Objetivo

O objetivo desta semana foi implementar e verificar a interface SPI e o modelo de PLL do MiniSoC AES, conforme as seções 4.1, 5, 6 e 9 do Block Guide.

As atividades contemplaram:

- Implementação do `minisoc_spi`, incluindo recepção e transmissão serial, sincronização entre domínios de clock e banco de registradores.
- Implementação do `minisoc_pll_mock`, com divisores selecionáveis, aquisição pseudoaleatória de lock e controle da liberação do clock de sistema.
- Desenvolvimento de testbenches dirigidos para os dois módulos e para sua integração.
- Análise de lint e automação da regressão pelo Makefile.

## 2. Implementações realizadas

### 2.1. SPI Front-End

**Arquivo:** `rtl/minisoc_spi/minisoc_spi.sv`

A interface SPI foi implementada no Mode 0, com amostragem de MOSI na borda de subida de `spi_sclk_i` e atualização de MISO na borda de descida durante a transação. Os bits são transmitidos na ordem MSB-first.

O frame possui 40 bits, organizados da seguinte forma:

| Campo | Posição | Largura | Função |
|---|---|---:|---|
| RWb | 39 | 1 | Seleciona escrita (0) ou leitura (1) |
| ADDR | 38:33 | 6 | Endereço do registrador |
| RSV | 32 | 1 | Campo reservado |
| DATA | 31:0 | 32 | Dados da transação |

A recepção utiliza um registrador de deslocamento de 40 bits e um contador saturado. Quando o último bit é recebido e o buffer está disponível, o frame completo é publicado para o domínio always-on. Transações interrompidas antes dos 40 bits não são processadas, e bits adicionais são ignorados até a próxima ativação de CS.

A escrita é realizada em uma transação. A leitura utiliza duas transações: a primeira seleciona o endereço e armazena o valor lido; a segunda utiliza o endereço reservado NOP (`0x3F`) para recuperar a resposta.

Como convenções locais da implementação, o cabeçalho NOP utiliza `8'hFE` (RWb=1 e RSV=0), e os dados retornam nos últimos 32 bits do frame MISO, precedidos de oito bits iguais a zero. O valor da constante VERSION adotado foi `32'h0001_0000`. Essas convenções devem ser preservadas na integração com o mestre SPI.

### 2.2. Sincronização entre domínios de clock (CDC)

A recepção serial opera no domínio `spi_sclk_i`, enquanto o banco de registradores opera no domínio always-on `clk_i`.

A transferência do frame utiliza um handshake baseado em toggle. Após a recepção completa, o conteúdo é armazenado em `rx_frame_q` e o sinal `req_toggle_q` é alternado. A requisição atravessa um sincronizador de dois flip-flops (`req_meta_q` e `req_sync_q`). No domínio always-on, o frame é capturado em `frame_sys_q` e processado mediante `frame_valid_q`.

Após o processamento, `ack_toggle_q` confirma a operação. A confirmação retorna ao domínio SPI através de `ack_meta_q` e `ack_sync_q`, permitindo a reutilização do buffer. Os dados do frame permanecem estáveis durante a transferência. O buffer de resposta de leitura é disponibilizado ao transmissor mediante o controle de validade e a confirmação da requisição.

A estratégia evita a necessidade de uma FIFO assíncrona para o protocolo adotado. A simulação funcional verifica os cenários dirigidos, mas não substitui uma análise física de CDC ou de temporização.

### 2.3. Banco de registradores

O banco foi implementado conforme o mapa de endereços da seção 6 do Block Guide.

| Endereço | Registrador | Acesso |
|---|---|---|
| 0x00–0x03 | KEY0–KEY3 | R/W |
| 0x04–0x07 | IV0–IV3 | R/W |
| 0x08–0x09 | COUNTER_HI/COUNTER_LO | R/W |
| 0x0A | NUM_BLOCKS | R/W |
| 0x0B | AES_CONTROL | R/W |
| 0x0C | AES_STATUS | R |
| 0x0D | VERSION | R |
| 0x0E | SYSTEM_CONTROL | R/W |
| 0x0F | SYSTEM_STATUS | R |
| 0x3F | NOP | Reservado |

Os registradores de chave e IV são agrupados em saídas de 128 bits, e os registradores do contador em uma saída de 64 bits. O NUM_BLOCKS preserva os 32 bits recebidos, evitando truncamento antes de uma futura validação pelo controlador AES.

O campo START de AES_CONTROL foi implementado como *write-one-pulse*. Uma escrita com START=1 gera um pulso de um ciclo de `clk_i`; o campo não permanece armazenado como um bit de controle ativo. Os registradores somente leitura não são modificados por comandos de escrita.

Nesta etapa, os sinais de status do AES foram fornecidos pelo testbench. A integração com o AES Engine não faz parte da verificação da Semana 5.

### 2.4. PLL mock

**Arquivo:** `rtl/minisoc_pll/minisoc_pll_mock.sv`

O PLL mock é um modelo RTL de integração, não uma macro física de PLL. Utiliza o clock de referência de 2 GHz e disponibiliza quatro opções de divisão:

| PLL_DIV_SEL | Divisor | Frequência | Período |
|---|---|---:|---:|
| 00 | /1 | 2 GHz | 0,5 ns |
| 01 | /2 | 1 GHz | 1 ns |
| 10 | /4 | 500 MHz | 2 ns |
| 11 | /8 | 250 MHz | 4 ns |

As divisões /2, /4 e /8 são produzidas pelos três bits de um contador compartilhado; a divisão /1 utiliza diretamente a referência.

A aquisição de lock utiliza um LFSR de 8 bits, com semente não nula, para determinar uma espera interna entre 8 e 23 ciclos de referência. A latência externa pode incluir ciclos adicionais necessários à liberação do clock em fase segura.

O controle é realizado por uma máquina de estados finitos:

| Estado | Responsabilidade |
|---|---|
| `ST_DISABLED` | Aguarda habilitação com a saída bloqueada |
| `ST_ACQUIRING` | Aguarda a conclusão da contagem de aquisição |
| `ST_LOCKED` | Solicita a liberação do clock e mantém a operação até a desabilitação |

A seleção do divisor é capturada ao iniciar uma nova aquisição. Uma mudança de divisor durante a operação não modifica imediatamente a frequência de saída; é necessário desabilitar e reabilitar o PLL.

O clock gating utiliza um latch que permite atualizar a habilitação durante a fase baixa do clock selecionado. O sinal `pll_locked_o` depende da conclusão da aquisição, do enable, do reset e da habilitação do gate. Na desabilitação normal, o lock cai e um pulso alto em andamento pode terminar antes do bloqueio. O reset global pode interromper a saída imediatamente.

Essa estratégia foi verificada em simulação RTL. A implementação física exigirá recursos apropriados de seleção e gating de clocks, além da análise de temporização.

## 3. Metodologia de verificação

Foram desenvolvidos três testbenches dirigidos e autoverificáveis. Os estímulos utilizam SPI a 25 MHz e clock de referência de 2 GHz, com resolução temporal de 1 ps.

### 3.1. Verificação do SPI Front-End

**Testbench:** `tb/minisoc_spi_tb.sv`

| Grupo | Cenário | Resultado |
|---|---|---|
| 01 | Reset e leituras iniciais | PASS |
| 02 | Escrita e leitura de KEY, IV, COUNTER e NUM_BLOCKS | PASS |
| 03 | AES_CONTROL e pulso START | PASS |
| 04 | SYSTEM_CONTROL e quatro seleções de divisor | PASS |
| 05 | Proteção de AES_STATUS, VERSION e SYSTEM_STATUS | PASS |
| 06 | Preservação da resposta durante NOP | PASS |
| 07 | Frames incompletos, RSV inválido e endereço não mapeado | PASS |
| 08 | Contador saturado em 40 bits | PASS |
| 09 | NOP interrompido, repetido e inválido | PASS |
| 10 | Reset com leitura pendente e recuperação | PASS |

Todos os 13 registradores R/W foram escritos e lidos. Os três registradores R foram submetidos a tentativas de escrita e seus valores permaneceram inalterados.

**Resultado:** 61 verificações aprovadas e zero falhas.

### 3.2. Verificação do PLL mock

**Testbench:** `tb/minisoc_pll_mock_tb.sv`

Foram verificados o reset, a interrupção da aquisição, os quatro divisores, os períodos e o duty cycle, a estabilidade da seleção durante a operação, a variação pseudoaleatória da aquisição, o bloqueio do clock e a recuperação após reset.

A aquisição de lock foi confirmada nos quatro divisores. As primeiras habilitações de cada divisor apresentaram os seguintes resultados no teste individual:

| Divisor | Alvo interno de aquisição | Latência externa de lock | Período esperado |
|---|---:|---:|---:|
| /1 | 18 ciclos | 19 ciclos | 0,5 ns |
| /2 | 16 ciclos | 18 ciclos | 1 ns |
| /4 | 13 ciclos | 15 ciclos | 2 ns |
| /8 | 22 ciclos | 27 ciclos | 4 ns |

Foram observados dez alvos distintos para a espera pseudoaleatória na execução registrada. Os testes de período e duty cycle de 50% passaram para os quatro divisores.

#### Correção no ambiente de verificação

Na primeira execução do testbench do PLL, foram reportadas 14 falhas em 132 verificações. Todas estavam associadas à leitura de `pll_locked_o` imediatamente após a alteração de `pll_enable_i` para zero.

A causa foi identificada como uma condição de corrida na amostragem: a verificação podia ocorrer antes da reavaliação da atribuição contínua do sinal de lock. Foi acrescentada uma espera de 1 ps no testbench antes de consultar o sinal:

```systemverilog
#0.05 pll_enable_i = 1'b0;
#0.001;
check("LOCK cai imediatamente com enable=0",
      pll_locked_o === 1'b0);
```

Após essa alteração, todas as 132 verificações passaram, sem necessidade de modificar o RTL do PLL para resolver essas falhas. A espera de 1 ps é um recurso de simulação, e não um atraso inserido no hardware.

**Resultado:** 132 verificações aprovadas e zero falhas na regressão após a correção.

### 3.3. Verificação integrada SPI + PLL

**Testbench:** `tb/minisoc_spi_pll_tb.sv`

O testbench conecta os dois módulos diretamente. O SPI fornece `pll_enable_o` e `pll_div_sel_o` ao PLL, enquanto o PLL retorna `pll_locked_o` ao registrador SYSTEM_STATUS e gera `sys_clk_o`.

Foram realizados sete grupos de testes: reset inicial, configuração dos quatro divisores, mudança de divisor durante a operação e recuperação após reset global.

A versão final inclui uma tarefa de polling de SYSTEM_STATUS (READ + NOP), com limite de quatro tentativas, para aguardar PLL_LOCKED=1. Dessa forma, o teste contempla os passos 8 e 9 do modelo de programação da seção 9 do Block Guide. Como a aquisição do PLL é muito mais rápida do que uma transação SPI, o lock foi encontrado na primeira consulta nos cenários executados, conforme o total de verificações observado. O caminho de repetição após uma leitura sem lock não foi exercitado nessa execução.

**Resultado:** 97 verificações aprovadas e zero falhas na versão atualizada com polling.

## 4. Análise de lint

A análise foi realizada com Synopsys Vlogan, versão X-2025.06-SP2, utilizando `+lint=all` e escala de tempo `1ns/1ps`. A regressão final foi executada em 27/11/2026.

Não foram reportados erros de compilação nem avisos de lint nos módulos RTL. Foram identificados 27 avisos, todos do tipo `Lint-[NS] Null statement`, exclusivamente nos testbenches.

| Arquivo | Quantidade |
|---|---:|
| `rtl/minisoc_spi/minisoc_spi.sv` | 0 |
| `rtl/minisoc_pll/minisoc_pll_mock.sv` | 0 |
| `tb/minisoc_spi_tb.sv` | 0 |
| `tb/minisoc_pll_mock_tb.sv` | 20 |
| `tb/minisoc_spi_pll_tb.sv` | 7 |
| **Total** | **27** |

### 4.1. Justificativa dos avisos do testbench PLL

| Linhas | Construção | Quantidade | Justificativa |
|---|---|---:|---|
| 78, 211, 234, 265 | `repeat (...) @(negedge clk_i);` | 4 | Espera de ciclos para verificar bloqueio, aquisição e variação da latência |
| 110 | `@(negedge clk_i);` | 1 | Amostragem do status em fase distinta da atualização sequencial |
| 159, 165, 194 | `@(posedge sys_clk_o);` | 3 | Referência para medição de período e duração do pulso |
| 163, 204 | `@(negedge sys_clk_o);` | 2 | Medição da duração dos pulsos altos |
| 79, 111, 199, 212, 235, 277 | `#0.001;` | 6 | Espera de 1 ps para estabilização dos sinais antes das verificações |
| 90 | `#1.1;` | 1 | Duração do reset |
| 92, 226 | `#0.1;` | 2 | Temporização dos estímulos e estabilização inicial |
| 299 | `#5000;` | 1 | Timeout global da simulação |
| **Total** | | **20** | |

### 4.2. Justificativa dos avisos do testbench integrado

| Linha | Construção | Justificativa |
|---:|---|---|
| 93 | `#2.3;` | Tempo de setup após a ativação do Chip Select |
| 96 | `#20;` | Temporização da fase baixa do SPI a 25 MHz |
| 103 | `#3;` | Intervalo após a transação SPI |
| 159 | `#8;` | Tempo para conclusão de eventual último pulso de clock |
| 161 | `#8;` | Janela de observação da ausência de novas bordas |
| 206 | `#2;` | Estabilização após o reset inicial |
| 282 | `#0.001;` | Espera de 1 ps para atualização dos sinais após reset |

As instruções de espera por eventos e os atrasos temporais com comando vazio são construções válidas em SystemVerilog para o ambiente de simulação. São utilizadas intencionalmente para sincronizar estímulos, medir clocks, evitar corridas de amostragem e limitar a duração dos testes. Não integram a lógica RTL destinada à implementação física.

Na regressão anterior à atualização do polling havia 28 avisos. Na versão final, o atraso isolado do timeout global integrado foi associado à chamada de `$fatal`, eliminando esse aviso e reduzindo o total para 27.

**Resultado:** análise Vlogan concluída sem erros, com 27 avisos identificados e justificados nos testbenches. Não foram observadas falhas funcionais na regressão final. Esta análise corresponde ao lint disponibilizado pelo Vlogan, não a uma execução dedicada de SpyGlass, análise de CDC ou sign-off de temporização.

## 5. Automação dos testes

O Makefile foi atualizado com o alvo:

```bash
make semana5-synopsys
```

O comando verifica a disponibilidade das ferramentas e dos arquivos, analisa os dois módulos RTL e os três testbenches com Vlogan e executa a elaboração e simulação de cada testbench com VCS.

Para registrar a saída da regressão:

```bash
set -o pipefail
make semana5-synopsys 2>&1 | tee semana5_synopsys.log
```

O comando foi executado com sucesso no servidor em 27/11/2026, após a atualização do testbench integrado. A mensagem final foi:

```text
PASS: Semana 5 - Testes Synopsys concluidos!
```

## 6. Resultados obtidos

| Testbench | Verificações | Falhas | Resultado |
|---|---:|---:|---|
| SPI Front-End | 61 | 0 | PASS |
| PLL mock | 132 | 0 | PASS |
| SPI + PLL | 97 | 0 | PASS |
| **Total** | **290** | **0** | **PASS** |

### 6.1. Critérios de aceite

| Critério | Evidência | Resultado |
|---|---|---|
| Todos os registradores R/W escritos e lidos via SPI | 13 registradores R/W verificados no teste individual do SPI | Atendido |
| Registradores R não alterados por escrita | Tentativas de escrita em AES_STATUS, VERSION e SYSTEM_STATUS | Atendido |
| PLL adquirindo lock nos quatro divisores | Testes individuais e integrados de /1, /2, /4 e /8 | Atendido |
| Lint sem erros e com avisos justificados | 27 avisos exclusivamente nos testbenches, conforme seção 4 | Atendido |

## 7. Conclusão

Foram implementados os módulos SPI Front-End e PLL mock, incluindo a comunicação entre os domínios de clock, o banco de registradores, a geração das quatro frequências e a aquisição pseudoaleatória de lock.

Os três testbenches demonstraram o funcionamento individual e integrado dos módulos nos cenários dirigidos, com 290 verificações aprovadas e zero falhas. A regressão automatizada pelo Makefile foi concluída com sucesso, e os 27 avisos de lint remanescentes foram identificados e justificados.

Os resultados atendem aos critérios funcionais de aceite da Semana 5. A integração com o AES Engine, a memória compartilhada, a sequência definitiva de reset do sistema e as análises físicas de CDC e temporização permanecem fora do escopo da verificação desta etapa.
