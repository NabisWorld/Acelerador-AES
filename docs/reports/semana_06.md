# Relatório — Semana 6

## 1. Objetivo

O objetivo desta semana é implementar e verificar a memória compartilhada e o controlador AES do MiniSoC, conforme as seções 7 e 8 do Block Guide, contemplando o processamento de múltiplos blocos nos modos ECB, CBC e CTR.

As atividades contemplam:

- Implementação da memória compartilhada de 1024 palavras de 32 bits.
- Implementação do `minisoc_aes_top`, integrado à expansão de chaves e ao datapath AES.
- Processamento in-place de 1 a 256 blocos, nas direções de cifragem e decriptação.
- Desenvolvimento de um modelo de referência em Python e de testbenches autoverificáveis.
- Análise de lint e automação da regressão pelo Makefile.

Este relatório registra o desenvolvimento parcial da Semana 6.

## 2. Implementações realizadas

### 2.1. Memória compartilhada

**Arquivo:** `rtl/minisoc_mem/minisoc_memory.sv`

A memória foi implementada como single-port, com leitura e escrita síncronas e sem reset do conteúdo armazenado.

| Característica | Valor |
|---|---|
| Profundidade | 1024 palavras |
| Largura da palavra | 32 bits |
| Largura do endereço | 10 bits |
| Capacidade | 4096 bytes |
| Capacidade em blocos AES | 256 |

Cada bloco de 128 bits ocupa quatro endereços consecutivos, com a palavra mais significativa armazenada no primeiro endereço. Para um bloco de índice `i`, o endereço base corresponde a `4*i`.

| Endereço relativo | Bits do bloco |
|---|---|
| 0 | 127:96 |
| 1 | 95:64 |
| 2 | 63:32 |
| 3 | 31:0 |

O sinal `MEM_SEL_AES` seleciona o proprietário da memória, permitindo o acesso pela interface externa ou pelo AES Engine. A transferência segura de propriedade entre domínios de clock deverá ser consolidada na integração completa do MiniSoC.

### 2.2. Controlador AES

**Arquivo:** `rtl/minisoc_aes/minisoc_aes_top.sv`

O controlador coordena a expansão de chaves, a leitura dos blocos, o processamento criptográfico e a escrita dos resultados na memória.

Ao receber um START válido, são capturados internamente KEY, IV, COUNTER, MODE, DECRYPT e NUM_BLOCKS. Dessa forma, alterações nas entradas de configuração durante BUSY não devem modificar a operação em andamento.

O campo NUM_BLOCKS é validado com sua largura original de 32 bits antes do armazenamento interno em nove bits. São aceitas quantidades de 1 a 256 blocos.

A máquina de estados foi organizada da seguinte forma:

| Estado | Responsabilidade |
|---|---|
| `ST_IDLE` | Aguarda START e valida as configurações |
| `ST_SETUP` | Aguarda a expansão das chaves |
| `ST_READ_BLOCK` | Recupera as quatro palavras do bloco |
| `ST_PREP_AES` | Prepara a entrada do datapath |
| `ST_AES_RUN` | Aguarda a conclusão do datapath |
| `ST_POST_AES` | Realiza o pós-processamento e atualiza IV ou contador |
| `ST_WRITE_BLOCK` | Escreve o resultado na memória |
| `ST_CHECK_BLOCK` | Atualiza a contagem e verifica se existem blocos restantes |
| `ST_FINISH` | Sinaliza a conclusão da operação |

Após `ST_CHECK_BLOCK`, o controlador retorna a `ST_READ_BLOCK` caso existam blocos restantes. Caso contrário, segue para `ST_FINISH` e retorna a `ST_IDLE`.

A expansão das onze chaves de rodada (K0–K10) é realizada uma única vez por operação. O datapath iterativo desenvolvido nas semanas anteriores é reutilizado para todos os blocos.

### 2.3. Acesso à memória

A leitura utiliza dois ciclos por palavra: um para a leitura síncrona e outro para a captura do dado. A escrita utiliza um ciclo por palavra.

| Operação | Ciclos por palavra | Ciclos por bloco |
|---|---:|---:|
| Leitura | 2 | 8 |
| Escrita | 1 | 4 |

O processamento é realizado in-place, sobrescrevendo os quatro endereços originais após a conclusão do processamento criptográfico.

O endereço é formado pela concatenação dos oito bits inferiores do índice do bloco com os dois bits do índice da palavra. No cenário de 256 blocos, o último bloco ocupa os endereços 1020 a 1023. A contagem de blocos concluídos possui nove bits para representar o valor 256 sem truncamento.

A estratégia inicial prioriza a simplicidade do controle e da verificação.

### 2.4. Modos de operação

| MODE | Modo | Situação |
|---|---|---|
| 000 | ECB | Implementado |
| 001 | CBC | Implementado |
| 010 | PCBC | Previsto para a Semana 10 |
| 011 | CFB | Previsto para a Semana 10 |
| 100 | OFB | Previsto para a Semana 10 |
| 101 | CTR | Implementado |
| 110–111 | Reservado | Rejeitado |

#### ECB

Cada bloco é encaminhado diretamente ao datapath, utilizando a primitiva AES Encrypt ou AES Decrypt conforme a direção selecionada. Não existe dependência entre blocos consecutivos.

#### CBC

Na cifragem, o bloco de entrada é combinado por XOR com o IV ou com o ciphertext anterior antes da aplicação de AES Encrypt.

Na decriptação, o XOR é realizado após AES Decrypt. O ciphertext original é preservado internamente antes da escrita in-place, pois será utilizado na decriptação do próximo bloco.

#### CTR

O bloco utilizado para gerar o keystream é formado conforme a especificação do MiniSoC:

```text
T_i = IV XOR {64'b0, COUNTER_i}
S_i = AES_Encrypt(KEY, T_i)
OUT_i = IN_i XOR S_i
```

A primitiva AES Encrypt é utilizada nas duas direções. O contador de 64 bits é incrementado após cada bloco, enquanto o IV permanece inalterado.

A política para overflow completo do contador ainda deverá ser confirmada.

### 2.5. Controle e status

| Sinal | Comportamento implementado |
|---|---|
| BUSY | Indica operação em andamento |
| DONE | Permanece ativo após a conclusão até um novo START válido ou reset |
| ERROR | Indica configuração inválida |
| BLOCKS_DONE | Contabiliza os blocos após a escrita na memória |

São rejeitados valores de NUM_BLOCKS fora do intervalo permitido, modos reservados e modos ainda não implementados. Comandos START durante BUSY são ignorados.

Esses comportamentos estão implementados no RTL, mas ainda deverão ser verificados por simulação integrada.

## 3. Metodologia de verificação

### 3.1. Verificação unitária da memória

Foi desenvolvido um testbench dirigido para verificar a leitura, a escrita e a seleção do proprietário da memória.

**Resultado:** testes unitários aprovados conforme a execução registrada durante o desenvolvimento. O total de verificações não foi consolidado neste relatório parcial.

### 3.2. Modelo de referência em Python

**Arquivo previsto:** `scripts/generate_aes_vectors.py`

O Golden Model está sendo desenvolvido no Google Colab utilizando a biblioteca PyCryptodome. Seu objetivo é produzir resultados independentes do RTL para comparação automática no testbench.

A validação inicial utiliza o seguinte vetor conhecido do AES-128:

| Parâmetro | Valor |
|---|---|
| KEY | `000102030405060708090A0B0C0D0E0F` |
| Plaintext | `00112233445566778899AABBCCDDEEFF` |
| Ciphertext | `69C4E0D86A7B0430D8CDB78070B4C55A` |

A cifragem e a decriptação são verificadas separadamente contra os valores conhecidos.

Os modos ECB e CBC utilizam as implementações nativas da biblioteca. Para CTR, foi elaborada uma função específica utilizando AES em ECB para gerar o keystream, respeitando a formação do contador definida pelo Block Guide.

Foram elaborados testes com vetores conhecidos (KAT) e testes de reversibilidade (round-trip). A reversibilidade, isoladamente, não comprova a conformidade criptográfica.

### 3.3. Geração dos cenários

Foi definido um conjunto de 256 blocos, composto por quatro blocos conhecidos do NIST SP 800-38A e 252 blocos pseudoaleatórios gerados com seed fixa.

| Parâmetro | Valor |
|---|---|
| KEY | `2B7E151628AED2A6ABF7158809CF4F3C` |
| IV | `000102030405060708090A0B0C0D0E0F` |
| COUNTER | `01234567FFFFFF80` |
| Seed | 2026 |

A escolha do contador permite exercitar a propagação do carry entre suas metades de 32 bits.

| Índice do bloco | Contador esperado |
|---:|---|
| 0 | `01234567FFFFFF80` |
| 127 | `01234567FFFFFFFF` |
| 128 | `0123456800000000` |
| 255 | `012345680000007F` |

A matriz contempla 18 cenários, totalizando 1554 blocos e 6216 palavras de 32 bits por conjunto acumulado de entradas ou saídas.

| Modo | Direção | 1 bloco | 2 blocos | 256 blocos |
|---|---|---|---|---|
| ECB | Encrypt | Pendente | Pendente | Pendente |
| ECB | Decrypt | Pendente | Pendente | Pendente |
| CBC | Encrypt | Pendente | Pendente | Pendente |
| CBC | Decrypt | Pendente | Pendente | Pendente |
| CTR | Encrypt | Pendente | Pendente | Pendente |
| CTR | Decrypt | Pendente | Pendente | Pendente |

A situação indicada corresponde à simulação do RTL. Os ciphertexts de entrada dos testes de decriptação são produzidos pelo modelo de referência, sem depender da cifragem realizada pelo hardware.

### 3.4. Exportação dos vetores

Foi elaborado o código de exportação dos dados em palavras de 32 bits, na ordem big-endian, para leitura pelo SystemVerilog através de `$readmemh`.

| Arquivo | Conteúdo |
|---|---|
| `config.hex` | Configurações e status esperados |
| `input.hex` | Dados de entrada |
| `expected.hex` | Dados esperados |
| `manifest.txt` | Identificação dos cenários |

A estrutura prevê 54 arquivos hexadecimais e um manifesto, além do pacote `aes_test_vectors.zip` para transferência dos arquivos do Colab.

**Situação:** código de geração e exportação elaborado. A execução consolidada do notebook e a conferência dos arquivos ainda estão pendentes.

### 3.5. Verificação integrada AES + memória

**Testbench previsto:** `tb/minisoc_aes_top_tb.sv`

O testbench deverá carregar os vetores, inicializar a memória, configurar o AES Engine, emitir START, aguardar DONE com timeout e comparar cada palavra resultante com o Golden Model.

Além dos 18 cenários criptográficos, deverão ser verificados:

- NUM_BLOCKS igual a zero, superior a 256 e com bits superiores ativos.
- Modos reservados e modos temporariamente não suportados.
- START durante BUSY e alteração das configurações durante a operação.
- Permanência de DONE, limpeza em novo START válido e atualização de BLOCKS_DONE.
- Operações consecutivas, mudança de chave e reset durante o processamento.
- Preservação dos endereços não utilizados e ausência de escritas indevidas.

**Situação:** testbench integrado e respectivas simulações pendentes.

## 4. Análise de lint e elaboração

Durante o desenvolvimento do `minisoc_aes_top`, foram identificados problemas estruturais em uma versão intermediária do arquivo, incluindo um `endmodule` prematuro e a ausência do estado `ST_AES_RUN`. Esses problemas foram corrigidos.

A elaboração mais recente com Synopsys VCS X-2025.06-SP2 utilizou o módulo `minisoc_aes_top` como top, com escala de tempo `1ns/1ps` e geração da base KDB para o Verdi.

**Resultado:** compilação e elaboração concluídas com sucesso, sem erros ou avisos no trecho de log apresentado.

A elaboração não substitui a simulação funcional. A análise final de lint com Vlogan ainda deverá ser consolidada após a construção do testbench integrado. Não há, neste momento, uma contagem final de avisos da Semana 6.

## 5. Automação dos testes

A atualização do Makefile para a regressão completa da Semana 6 permanece pendente.

A regressão deverá contemplar a análise dos módulos RTL e testbenches com Vlogan, a elaboração e simulação com VCS e a emissão de um resultado consolidado. O alvo e os comandos definitivos deverão ser confirmados após a integração dos testes.

O notebook, o script Python e os vetores de referência também deverão ser organizados no repositório para permitir a reprodução dos testes.

## 6. Resultados obtidos

| Atividade | Resultado atual |
|---|---|
| Memória compartilhada | Implementada |
| Testbench unitário da memória | PASS |
| Controlador AES e FSM | Implementados |
| Integração estrutural com datapath e expansão de chaves | Implementada |
| ECB, CBC e CTR | Implementados, aguardando verificação |
| Compilação e elaboração do controlador | Concluídas |
| Golden Model e exportação | Em finalização |
| Testbench integrado | Pendente |
| Simulação dos 18 cenários | Pendente |
| Lint e regressão final | Pendentes |

### 6.1. Critérios de aceite

| Critério | Evidência atual | Resultado |
|---|---|---|
| Memória 1024 × 32 bits, single-port e síncrona | Implementação e teste unitário | Atendido no teste unitário |
| Processamento in-place de 1 a 256 blocos | Lógica de leitura, escrita e endereçamento implementada | A validar |
| ECB, CBC e CTR nas duas direções | RTL implementado; vetores de referência elaborados | A validar |
| Comparação com software para 1, 2 e 256 blocos | Matriz de 18 cenários elaborada | Pendente |
| Controle de status e rejeição de configurações inválidas | Lógica implementada | A validar |
| Lint sem erros e avisos justificados | Elaboração bem-sucedida; lint final não consolidado | Pendente |

### 6.2. Atividades restantes

1. Executar e validar integralmente o Golden Model, conferindo os arquivos exportados.
2. Organizar o notebook, o script Python e os vetores no GitHub.
3. Implementar o testbench integrado AES + memória.
4. Executar os 18 cenários criptográficos e corrigir eventuais divergências.
5. Executar os testes de controle e condições excepcionais.
6. Consolidar o lint, atualizar o Makefile e executar a regressão final.
7. Registrar os resultados e atualizar os critérios de aceite deste relatório.

### 6.3. Melhoria adicional proposta

Após a aprovação funcional da implementação atual, poderá ser avaliada uma leitura com pipeline, sobrepondo a solicitação da próxima palavra à captura da palavra anterior.

| Estratégia | Ciclos de leitura por bloco |
|---|---:|
| Atual | 8 |
| Pipeline proposto | 5 |

A redução teórica é de 37,5% na etapa de leitura, equivalente a 768 ciclos para 256 blocos. Não se trata de uma medição do desempenho total do AES Engine.

Essa otimização é uma melhoria adicional, não um requisito obrigatório identificado para a Semana 6. Caso seja implementada, deverá ser seguida de uma nova regressão funcional.

## 7. Conclusão parcial

Foram implementados a memória compartilhada e o controlador AES, incluindo a máquina de estados, o processamento in-place, a captura das configurações e os modos ECB, CBC e CTR.

A memória apresentou aprovação nos testes unitários, e o controlador foi compilado e elaborado com sucesso nas ferramentas Synopsys. O modelo de referência em Python encontra-se em fase de finalização, com a geração e exportação dos 18 cenários elaboradas.

A correção funcional do AES Engine ainda deverá ser demonstrada pela comparação dos resultados do RTL com o Golden Model. A conclusão da Semana 6 depende da execução dos testes integrados, da verificação dos comportamentos de controle e da consolidação da regressão e do lint.

Os modos PCBC, CFB e OFB permanecem previstos para a Semana 10. A transferência segura de propriedade da memória entre domínios de clock e a sequência definitiva de reset permanecem atividades de integração do sistema completo.
