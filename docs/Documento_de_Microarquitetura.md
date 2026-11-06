
# Documento de Microarquitetura — MiniSoC AES

> **Projeto:** Acelerador AES com Interface SPI e Baixo Consumo  
> **Etapa:** Semana 3 — Definição da microarquitetura.  
> **Versão:** 1.0 — Em elaboração  

## 1. Objetivo

Este documento apresenta a microarquitetura proposta para o MiniSoC AES, descrevendo a organização interna do acelerador, o processamento AES-128, o controle por máquinas de estados finitos (FSM), a estratégia de comunicação entre domínios de clock (CDC) e a sequência de reset.

As interfaces externas, o mapa de registradores, o protocolo SPI e a organização dos módulos seguem o *DV Block Guide MiniSoC AES v1.0.0*.

As decisões internas ainda não consolidadas serão identificadas como propostas ou pontos pendentes até a revisão da microarquitetura.

## 2. Arquitetura geral do sistema

*Tirado do Block Guide, seções 1 e 2.*
O MiniSoC apresenta quatro blocos funcionais:

| Bloco | Responsabilidade |
| :--- | :--- |
| **SPI Front-End** | Receber configurações e comandos e disponibilizar informações de status |
| **PLL mock** | Gerar o clock do sistema e controlar sua liberação |
| **AES Engine** | Executar operações de cifragem e decifragem AES-128 |
| **Memória compartilhada** | Armazenar os blocos de entrada e os resultados do processamento |

Além desses blocos, o sistema possui uma interface externa denominada `MEMORY DATA`, destinada à leitura e escrita da memória compartilhada quando esta não está sob controle do AES Engine.

O AES Engine deverá trabalhar com blocos de 128 bits, chaves de 128 bits e os modos ECB, CBC, PCBC, CFB, OFB e CTR.

A memória possui 1024 palavras de 32 bits, permitindo armazenar até 256 blocos AES. Cada bloco ocupa quatro endereços consecutivos. O processamento é realizado *in-place*, ou seja, o resultado substitui o bloco de entrada na memória.

A propriedade da memória é controlada por `MEM_SEL_AES`, garantindo acesso exclusivo ao AES Engine ou à interface externa.

## 3. Interfaces e organização dos módulos

*Tirado do Block Guide, seções 3 e 10.*

O módulo `minisoc_top.sv` deverá apresentar exatamente os grupos de interfaces definidos na especificação:

| Grupo | Sinais |
| :--- | :--- |
| CLK | `clk` |
| RESET | `rst_n` |
| SPI | `spi_sclk`, `spi_cs_n`, `spi_mosi`, `spi_miso` |
| MEMORY DATA | `mem_clk`, `mem_i_data`, `mem_i_wr_en`, `mem_i_addr`, `mem_o_data` |

As larguras dos sinais e o comportamento de cada interface deverão permanecer idênticos aos definidos no Block Guide.

Os principais módulos previstos são:

| Módulo | Responsabilidade |
| :--- | :--- |
| `minisoc_top` | Integrar os componentes e as interfaces do sistema. |
| `minisoc_spi` | Implementar a comunicação SPI e o acesso aos registradores de configuração e status. |
| `minisoc_pll_mock` | Implementar o modelo RTL de geração e controle do clock do sistema. |
| `minisoc_memory` | Implementar a memória compartilhada utilizada para armazenar os dados de entrada e saída. |
| `minisoc_aes_top` | Coordenar o funcionamento do AES Engine, incluindo o controle dos blocos e o acesso à memória. |
| `minisoc_aes_dp` | Implementar o datapath criptográfico responsável pelas transformações do AES-128. |
| `minisoc_aes_key_exp` | Realizar a expansão da chave original e disponibilizar as chaves necessárias às rodadas do AES-128. |

Essa organização permite definir responsabilidades individuais para os módulos, facilitando a implementação, os testes unitários e a integração progressiva do acelerador.

As decisões referentes à estrutura interna do AES Engine, ao controle das operações e à reutilização dos recursos de hardware serão detalhadas nas seções seguintes.

## 4. Registradores e protocolo SPI

*Tirado do Block Guide, seções 5 e 6.*

O SPI utilizará o modo 0 (CPOL = 0 e CPHA = 0), transmissão MSB-first e frequência máxima de 25 MHz.

Cada frame possui 40 bits, organizados em:

* **RWb:** 1 bit para identificar leitura ou escrita.
* **ADDR:** 6 bits para endereço do registrador.
* **RSV:** 1 bit reservado.
* **DATA:** 32 bits de dados.

As operações de escrita são realizadas em uma única transação SPI. Já as operações de leitura utilizam duas transações: a primeira solicita o conteúdo do registrador e a segunda permite retornar o valor solicitado.

Mapa de registradores pelo Block Guide:

| Endereços | Registradores |
| :--- | :--- |
| `0x00`–`0x03` | KEY0–KEY3 |
| `0x04`–`0x07` | IV0–IV3 |
| `0x08`–`0x09` | COUNTER_HI e COUNTER_LO |
| `0x0A` | NUM_BLOCKS |
| `0x0B` | AES_CONTROL |
| `0x0C` | AES_STATUS |
| `0x0D` | VERSION |
| `0x0E` | SYSTEM_CONTROL |
| `0x0F` | SYSTEM_STATUS |
| `0x3F` | NOP |

O comando START, associado ao controle do AES, solicita o início de uma nova operação por meio de uma escrita com valor 1. A aceitação da solicitação dependerá das condições de operação e configuração do sistema, conforme os requisitos do Block Guide.

O indicador DONE deverá permanecer ativo após a conclusão do processamento até que um novo comando START válido seja aceito, respeitando também as condições de reinicialização previstas na especificação.

A comunicação entre o domínio de clock da SPI e o domínio do sistema será realizada por meio de um mecanismo de sincronização CDC, detalhado na Seção 7.

## 5. Microarquitetura do AES-128

### 5.1. Estratégia de processamento — Arquitetura iterativa

Proposta escolhida: arquitetura iterativa, com uma rodada AES por ciclo de processamento.

Na arquitetura iterativa, uma única unidade de processamento das rodadas é reutilizada durante a execução do algoritmo AES-128, evitando a implementação de um circuito independente para cada rodada.

O processamento é organizado em torno de três componentes principais:

* **Registrador de estado de 128 bits:** armazena o estado atual do AES e os resultados intermediários das rodadas.
* **Contador de rodadas:** identifica a rodada em execução e auxilia na seleção das transformações e das chaves correspondentes.
* **Unidade de rodada AES:** executa as transformações criptográficas necessárias à cifragem ou decifragem, de acordo com os sinais de controle.

A proposta de uma rodada por ciclo refere-se à execução das rodadas no datapath. O processamento completo de um bloco também envolve etapas de inicialização, sinalização e controle, que serão coordenadas pela FSM interna do AES Core.

#### Pontos positivos da arquitetura iterativa:
* Reutilização da mesma unidade de processamento durante as rodadas.
* Menor duplicação de hardware.
* Controle das rodadas por meio de um contador, facilitando a organização do processamento.
* Menor complexidade inicial de implementação e verificação.
* Possibilidade de aplicar técnicas de redução de atividade dos circuitos nas etapas posteriores do projeto.

#### Pontos negativos:
* Necessidade de vários ciclos para concluir um bloco AES.
* Necessidade de lógica de controle, registradores e seleção dos caminhos de dados.
* O processamento de uma rodada inteira em um ciclo pode produzir um caminho combinacional longo, dificultando o atendimento às frequências mais elevadas.

### Justificativa da escolha
A arquitetura iterativa foi escolhida por favorecer a reutilização de recursos e permitir uma implementação progressiva e organizada do acelerador.

Embora apresente maior latência em comparação com determinadas arquiteturas paralelas, essa estratégia oferece um equilíbrio adequado entre complexidade de implementação e utilização de hardware.

Além disso, o Block Guide não estabelece uma exigência específica de vazão que obrigue a adoção de uma arquitetura totalmente desenrolada. A viabilidade da execução de uma rodada por ciclo, considerando as restrições de temporização, deverá ser avaliada nas etapas posteriores de integração e síntese.

---

### 5.2. Expansão de chave — Pré-computada sequencial

Proposta escolhida: expansão de chave pré-computada sequencial.

O AES-128 utiliza uma chave original de 128 bits, a partir da qual são obtidas as chaves necessárias ao processamento das rodadas. Ao todo, são utilizadas 11 chaves de 128 bits, identificadas de K0 a K10.

Na estratégia de expansão pré-computada sequencial, as chaves são preparadas ao longo de vários ciclos, antes do início do processamento dos blocos de dados.

O módulo de expansão de chave reutiliza sua lógica interna durante a geração das chaves, que posteriormente são armazenadas em um banco de registradores.

Dessa forma, durante a execução das rodadas AES, o datapath necessita apenas selecionar a chave correspondente à rodada atual, sem realizar novamente a expansão.

Na cifragem, as chaves são utilizadas na sequência K0 até K10. Na decifragem convencional, a utilização ocorre na ordem inversa, iniciando em K10 e terminando em K0.

Considerando que o MiniSoC AES poderá processar até 256 blocos por operação, a proposta é realizar a expansão uma única vez no início da operação e reutilizar as chaves armazenadas durante o processamento de todos os blocos.

#### Pontos positivos da expansão pré-computada sequencial:
* Disponibilidade das chaves antes do início do processamento dos blocos.
* Facilidade de seleção das chaves nas ordens direta e inversa.
* Simplificação do controle da cifragem e da decifragem.
* Reutilização das mesmas chaves durante o processamento de múltiplos blocos.
* Separação entre a preparação das chaves e a execução das rodadas, facilitando a implementação e a verificação.

#### Pontos negativos:
* Necessidade de armazenar 11 chaves de 128 bits, totalizando 1.408 bits.
* Introdução de ciclos adicionais de preparação antes do processamento.
* Necessidade de lógica para selecionar a chave correspondente a cada rodada.
* Maior quantidade de material criptográfico armazenado internamente, exigindo atenção ao controle de acesso e à limpeza das chaves.

#### Justificativa da escolha
A expansão pré-computada sequencial foi escolhida principalmente pela facilidade de utilização das chaves durante a decifragem e pela possibilidade de reutilizá-las ao longo do processamento de múltiplos blocos.

Embora exija armazenamento adicional, essa estratégia simplifica a seleção das chaves e separa sua geração da execução das rodadas, mantendo compatibilidade com a arquitetura iterativa proposta.

---

### 5.3. Organização dos caminhos de cifragem e decifragem

Proposta escolhida: caminhos parcialmente compartilhados.

O AES-128 utiliza transformações diferentes para realizar a cifragem e a decifragem dos blocos de dados.

> **Cifragem**  
> SubBytes → ShiftRows → MixColumns → AddRoundKey

> **Decifragem**  
> InvShiftRows → InvSubBytes → AddRoundKey → InvMixColumns

As transformações diretas e inversas serão implementadas em unidades específicas, enquanto os componentes com funções comuns poderão ser reutilizados.

Entre os recursos compartilhados estão o registrador de estado, o contador de rodadas, o banco de chaves, a lógica de controle e a unidade AddRoundKey.

Entretanto, como essa transformação ocupa posições diferentes nas sequências de cifragem e decifragem, serão necessários caminhos de seleção apropriados para permitir sua reutilização.

A escolha entre as transformações diretas e inversas será realizada por multiplexadores controlados pela FSM interna do AES Core. Esses componentes também permitirão selecionar as chaves de rodada e os caminhos específicos das etapas inicial e final do algoritmo.

#### Pontos positivos:
* Reutilização dos componentes comuns às operações de cifragem e decifragem.
* Menor duplicação de hardware em comparação com caminhos completamente independentes.
* Possibilidade de reduzir a área ocupada pelos circuitos.
* Separação das transformações diretas e inversas, facilitando seus testes unitários.

#### Pontos negativos:
* Necessidade de multiplexadores adicionais para selecionar os caminhos de processamento.
* Maior complexidade na organização das conexões internas.
* Necessidade de adaptar o caminho do AddRoundKey às diferentes posições ocupadas na cifragem e na decifragem.
* Possibilidade de aumento do atraso combinacional devido à lógica de seleção.

#### Justificativa da escolha
A organização parcialmente compartilhada foi escolhida por oferecer um equilíbrio entre a reutilização de hardware e a complexidade de implementação. Essa estratégia permite reduzir a duplicação de recursos comuns sem exigir que todas as transformações diretas e inversas sejam unificadas em um único circuito.

Além disso, a separação dos módulos de transformação é compatível com a metodologia de desenvolvimento adotada no projeto, permitindo a implementação e a verificação individual das operações antes de sua integração ao AES Core.

## 6. Controle por máquinas de estados finitos

Para a primeira versão do minisoc, foi escolhido trabalhar com duas máquinas de estados finitos:

* A FSM principal, localizada no módulo minisoc_aes_top, coordena a execução completa das operações, incluindo a aceitação de comandos, preparação das configurações, leitura dos blocos da memória, acionamento do núcleo AES, escrita dos resultados e atualização dos indicadores de status.
* A FSM do AES Core controla internamente as rodadas do algoritmo AES-128, seguindo uma arquitetura iterativa de uma rodada por ciclo.

Essa separação permite organizar o processamento em dois níveis: a FSM principal controla o fluxo dos blocos, enquanto a FSM do AES Core coordena as operações criptográficas realizadas sobre cada bloco.

### 6.1. FSM principal do AES Engine

Ela é composta por nove estados, responsáveis por coordenar as etapas de processamento de cada operação.

*Figura 1 — Diagrama simplificado da FSM principal, com nove estados.*



O diagrama apresenta as transições entre estados diferentes. As condições de permanência em ummesmo estado são descritas na Tabela 1. O reset possui prioridade global e retorna a controladora ao estado IDLE


 ### Tabela 1 — Transições da FSM principal

| Estado atual | Condição de transição | Ação | Próximo estado |
| :--- | :--- | :--- | :--- |
| S0 — IDLE | Nenhum START aceito | Aguardar comando | IDLE |
| IDLE | START com configuração inválida | Sinalizar ERROR | IDLE |
| IDLE | START válido e aceito | Capturar configurações | SETUP |
| SETUP | key_done = 0 | Inicializar controles, emitir key_start uma única vez e aguardar a expansão das chaves | SETUP |
| SETUP | key_done = 1 | Confirmar a disponibilidade das 11 chaves de rodada | READ_BLOCK |
| S2 — READ_BLOCK | Ainda não foram recebidas as 4 palavras | Solicitar e armazenar cada palavra de 32 bits após confirmação da leitura; avançar word_idx | READ_BLOCK |
| READ_BLOCK | Quarta palavra recebida | Concluir montagem do bloco de 128 bits | PREP_AES |
| S3 — PREP_AES | Entrada preparada | Registrar a entrada conforme o modo AES | AES_RUN |
| S4 — AES_RUN | aes_done = 0 | Emitir aes_start uma única vez e aguardar o processamento | AES_RUN |
| AES_RUN | aes_done = 1 | Capturar resultado do AES Core | POST_AES |
| S5 — POST_AES | Resultado preparado | Registrar o resultado e atualizar o encadeamento conforme o modo | WRITE_BLOCK |
| S6 — WRITE_BLOCK | Ainda não foram confirmadas as 4 escritas | Escrever cada palavra de 32 bits e avançar word_idx somente após confirmação | WRITE_BLOCK |
| WRITE_BLOCK | Quarta escrita confirmada | Concluir armazenamento do bloco | CHECK_BLOCK |
| S7 — CHECK_BLOCK | BLOCKS_DONE + 1 < NUM_BLOCKS | Incrementar BLOCKS_DONE e avançar para o próximo bloco | READ_BLOCK |
| CHECK_BLOCK | BLOCKS_DONE + 1 = NUM_BLOCKS | Incrementar BLOCKS_DONE e concluir o processamento | FINISH |
| S8 — FINISH | Finalização registrada | Desativar BUSY e ativar DONE | IDLE |

---

### 6.2. Regras gerais da FSM principal

Além das transições entre estados, a FSM principal deverá respeitar as seguintes regras de funcionamento:

1. Controle de inicialização: os sinais key_start e aes_start deverão ser emitidos apenas uma vez durante a ativação de seus respectivos estados, evitando solicitações repetidas enquanto os módulos permanecem ocupados.
2. Contadores: os estados READ_BLOCK e WRITE_BLOCK utilizarão o contador word_idx para acompanhar as quatro palavras de 32 bits de cada bloco. O avanço ocorrerá somente após a conclusão confirmada da operação de memória correspondente
3. Contagem de blocos: o indicador BLOCKS_DONE deverá representar a quantidade de blocos concluídos. Como a memória permite processar até 256 blocos por operação, a contagem interna utilizará 9 bits para representar valores de 0 a 256.
4. Indicador BUSY: deverá permanecer ativo durante a execução de uma operação e ser desativado após sua conclusão.
5. Indicador DONE: será ativado após a conclusão do processamento e deverá permanecer ativo até a aceitação de um novo START válido ou a ocorrência de reset.
6. Indicador ERROR: deverá sinalizar configurações inválidas identificadas durante a aceitação de solicitações. A política exata de limpeza desse indicador deverá ser confirmada conforme o Block Guide.
7. Propriedade da memória: as operações de leitura e escrita realizadas pelo AES Engine somente poderão ocorrer quando a memória estiver sob seu controle exclusivo. As condições de aceitação de START relacionadas à propriedade da memória ainda deverão ser confirmadas
8. START durante BUSY: a política proposta é não aceitar uma nova operação enquanto a atual estiver em processamento, respeitando as condições estabelecidas pelo Block Guide.

### 6.3. FSM do AES Core
A FSM do AES Core é responsável pelo controle interno das rodadas do algoritmo AES-128.

O núcleo utiliza uma arquitetura iterativa de uma rodada por ciclo, reutilizando os recursos do datapath
criptográfico ao longo da execução.

*Figura 2 — Diagrama simplificado da FSM do AES Core, com cinco estados.*


O diagrama mostra as transições entre estados diferentes. A permanência no estado ROUND durante a execução das rodadas intermediárias é descrita na Tabela 2.

### Tabela 2 — Tabela de transições da FSM AES Core

| Estado atual | Condição de transição | Ação | Próximo estado |
| :--- | :--- | :--- | :--- |
| IDLE | aes_start = 0 | Aguardar solicitação de processamento | IDLE |
| IDLE | aes_start = 1 | Capturar o bloco de 128 bits e a direção da operação | INIT |
| INIT | Inicialização concluída | Aplicar AddRoundKey inicial e inicializar round_idx = 1 | ROUND |
| ROUND | round_idx < 9 | Executar a rodada intermediária atual e incrementar round_idx | ROUND |
| ROUND | round_idx = 9 | Executar a nona rodada intermediária | FINAL_ROUND |
| FINAL_ROUND | Rodada final executada | Executar a décima rodada AES, sem MixColumns na cifragem (ou InvMixColumns na decifragem), e registrar o resultado de 128 bits | DONE |
| DONE | Resultado disponível | Emitir aes_done durante um ciclo | IDLE |

### 6.3.1. Funcionamento da FSM do AES Core

O processamento só é iniciado quando o AES Core recebe o sinal `aes_start` da FSM principal.

1. No estado INIT, o núcleo realiza a transformação inicial AddRoundKey e inicializa o contador de rodadas (`round_idx`).
2. No estado ROUND, são executadas as nove rodadas intermediárias, reutilizando o datapath a cada ciclo. O contador identifica a rodada atual e determina o momento de avançar para FINAL_ROUND.
3. No estado FINAL_ROUND, a décima e última rodada é executada.
4. Após a conclusão, o resultado de 128 bits é registrado e a FSM entra no estado DONE, emitindo `aes_done`, informando que o processamento do bloco terminou.
5. Posteriormente, retorna a IDLE, aguardando uma nova solicitação.
6. As 11 chaves de rodada são previamente geradas e armazenadas pelo módulo Key Expansion e reutilizadas durante o processamento dos blocos.

### 6.3.2. Controle de cifragem e decifragem

* A FSM do AES Core mantém a mesma sequência de estados para cifragem e decifragem. A diferença está nas operações realizadas pelo datapath e na ordem de utilização das chaves de rodada.
* Na cifragem, as chaves são utilizadas de K0 até K10. Na decifragem, são aplicadas de K10 até K0, juntamente com as transformações inversas correspondentes.
* Nos modos CFB, OFB e CTR, a FSM principal solicita a primitiva AES de cifragem independentemente do valor de DECRYPT, pois a recuperação dos dados nesses modos utiliza a saída da função de cifragem combinada com operações XOR.

### 6.4. Comunicação entre as FSMs e controle de reset

A comunicação entre as duas FSMs ocorre por meio dos sinais `aes_start` e `aes_done`.

A FSM principal disponibiliza o bloco preparado de 128 bits e a direção de processamento ao AES Core. Em seguida, emite um pulso `aes_start`, solicitando o início da operação criptográfica.

Após aceitar a solicitação, o AES Core executa as rodadas e disponibiliza o resultado por meio de `aes_output[127:0]`. Ao concluir, emite `aes_done` durante um ciclo, permitindo que a FSM principal capture o resultado e avance para POST_AES.

As duas FSMs operam no mesmo domínio de clock do sistema (`sys_clk`), utilizando comunicação síncrona. O sinal de conclusão deve estar associado à operação iniciada, e a saída criptográfica deve permanecer válida até ser capturada pela FSM principal.

O reset possui prioridade sobre ambas as controladoras, levando-as aos respectivos estados IDLE e reinicializando os controles internos. Sua liberação deve respeitar a sequência de inicialização do sistema estabelecida pelo Block Guide.

Caso ocorra reset durante uma operação, o processamento é interrompido e não é retomado automaticamente. Como a escrita é realizada *in-place*, os dados já modificados na memória não são restaurados pelo reset.

### 6.5. Pontos pendentes

Essa é a primeira versão da estrutura de funcionamento das FSMs, ainda pode sofrer alterações dependendo das outras escolhas do projeto e problemas futuros que forem acontecendo. É possível citar algumas condições que não foram definidas:

* Sobre como o START deve se comportar quando a memória ainda não pertence ao AES, incluindo o momento em que o comando pode ser aceito e as condições necessárias para a transferência de propriedade.
* Como funciona a política exata de limpeza do indicador ERROR, para garantir compatibilidade com o mapa de registradores e o comportamento de status exigido.
* Validação dos sinais de confirmação dos acessos de memória e os mecanismos internos utilizados para emitir `key_start` e `aes_start` apenas uma vez.