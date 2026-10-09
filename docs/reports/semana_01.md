# Relatório — Semana 1
Como resultado das metas da semana, temos:
- organização da estrutura de diretórios do repositório;
- estudo do algoritmo AES e do protocolo SPI
- criação de um exemplo RTL mínimo utilizando uma porta AND
- criação de um testbench para validação do exemplo mínimo;
- desenvolvimento do Makefile (tirado do exemplo feito pelo professor)

## 1. Advanced Encryption Standard — AES

### 1.1 Visão geral

O **Advanced Encryption Standard (AES)** é um algoritmo de criptografia baseado no Rijndael. O padrão foi definido para trabalhar com blocos de dados de 128 bits e permite o uso de chaves criptográficas de 128, 192 ou 256 bits.

Embora o tamanho da chave possa variar, o tamanho do bloco processado pelo AES permanece sempre igual a 128 bits. O que muda entre as três versões é principalmente o tamanho da chave e o número de rodadas executadas.

As configurações definidas pelo padrão são:

| Versão  | Chave    | Bloco    | Rodadas |
|---------|----------|----------|---------|
| AES-128 | 128 bits | 128 bits | 10      |
| AES-192 | 192 bits | 128 bits | 12      |
| AES-256 | 256 bits | 128 bits | 14      |

### 1.2 Conceitos principais

O **plaintext** representa o dado original fornecido ao processo de cifragem, enquanto o **ciphertext** corresponde ao resultado cifrado. O termo **Cipher** é utilizado para representar o conjunto de transformações que converte o plaintext em ciphertext utilizando uma chave criptográfica.

A **Cipher Key** corresponde à chave criptográfica original fornecida ao algoritmo. Essa chave é utilizada pelo processo chamado **Key Expansion**, responsável por gerar as diferentes **Round Keys**, ou chaves de rodada, utilizadas ao longo da cifragem.

Outro conceito importante é o **State**, que representa o estado intermediário dos dados durante a execução do AES. As principais transformações do algoritmo atuam sobre esse State, modificando seu conteúdo a cada etapa.

O padrão também utiliza o termo **word**, que corresponde a um conjunto de 32 bits, ou quatro bytes. Esse conceito aparece principalmente na representação da chave e no processo de expansão da chave.

### 1.3 Organização dos dados no State

O AES trabalha com blocos de 128 bits, equivalentes a 16 bytes.

Antes das transformações começarem, esses 16 bytes são organizados internamente no **State**. O State possui quatro linhas e quatro colunas, totalizando os mesmos 16 bytes do bloco de entrada.

Um ponto importante é que os bytes são organizados por colunas. Ou seja, os quatro primeiros bytes da entrada formam a primeira coluna, os quatro seguintes formam a segunda coluna e assim sucessivamente.

Durante o processo de cifragem, as diferentes transformações do AES alteram o conteúdo desse State. Ao final, o State resultante é convertido novamente em uma sequência de 128 bits para formar o ciphertext.

Essa organização é especialmente importante para uma implementação em hardware, pois a posição dos bytes precisa ser mantida corretamente para que os resultados estejam de acordo com o padrão.

### 1.4 Estrutura geral do processo de cifragem

O processo de cifragem do AES é dividido em uma etapa inicial, várias rodadas de processamento e uma rodada final.

Primeiramente, o bloco de entrada é transferido para o State. Em seguida, antes da primeira rodada, ocorre uma operação chamada **AddRoundKey**, que combina o State com a primeira chave de rodada.

Após essa etapa inicial, começam as rodadas principais do algoritmo.

Nas rodadas intermediárias, são executadas quatro transformações na seguinte ordem:

**SubBytes → ShiftRows → MixColumns → AddRoundKey**

O padrão define essas quatro operações como as principais transformações utilizadas pelo Cipher.

A última rodada apresenta uma diferença importante: ela não executa a transformação **MixColumns**.

Dessa forma, a rodada final utiliza apenas:

**SubBytes → ShiftRows → AddRoundKey**

No caso do AES-128, existem dez rodadas. As nove primeiras utilizam as quatro transformações, enquanto a décima rodada não utiliza MixColumns.

### 1.5 SubBytes

A transformação **SubBytes** realiza uma substituição em cada byte do State.

Para isso, o AES utiliza uma tabela chamada **S-box**. Cada byte do State é usado para localizar um novo valor nessa tabela, sendo então substituído pelo valor correspondente.

A substituição ocorre de forma independente para cada byte.

O padrão apresenta como exemplo o valor hexadecimal `53`. Consultando a S-box, esse valor é substituído por `ED`.

Essa transformação introduz uma característica não linear ao algoritmo, contribuindo para dificultar a relação direta entre os dados de entrada e os dados cifrados.

Para a implementação em hardware, a S-box pode ser entendida como uma estrutura que recebe um byte e retorna outro byte correspondente.

### 1.6 ShiftRows

A transformação **ShiftRows** atua sobre as linhas do State.

A primeira linha permanece na mesma posição. A segunda linha é deslocada em uma posição, a terceira em duas posições e a quarta em três posições. Os deslocamentos são realizados de forma cíclica, fazendo com que os bytes que ultrapassam o limite da linha retornem para o início.

Diferentemente do SubBytes, essa operação não modifica o valor dos bytes. Ela apenas altera suas posições dentro do State.

Essa reorganização ajuda a distribuir os bytes entre diferentes colunas antes da próxima transformação.

### 1.7 MixColumns

A transformação **MixColumns** atua sobre cada coluna do State individualmente.

Durante essa etapa, os quatro bytes de uma coluna são combinados para gerar quatro novos bytes. Dessa forma, cada byte resultante passa a depender dos demais bytes presentes naquela coluna.

O padrão define essa transformação utilizando operações matemáticas em um campo finito. Para este estudo inicial, o ponto principal é compreender que MixColumns realiza uma mistura dos bytes da coluna, aumentando a distribuição das informações dentro do State.

É importante lembrar que essa transformação é utilizada nas rodadas intermediárias, mas não é executada na última rodada do AES.

### 1.8 AddRoundKey

A transformação **AddRoundKey** combina o State com uma chave específica da rodada.

Essa combinação é realizada por meio da operação XOR entre os bytes do State e os bytes da **Round Key** correspondente.

Essa etapa é executada antes da primeira rodada e também ao final de cada rodada.

Uma distinção importante é que o algoritmo não utiliza exatamente a mesma chave em todas as rodadas. A chave original é usada para gerar diferentes chaves de rodada através do processo de **Key Expansion**.

### 1.9 Expansão da chave

O processo chamado **Key Expansion** é responsável por gerar as chaves utilizadas nas diferentes rodadas do AES.

A chave original é dividida em *words* e, a partir delas, novas *words* são produzidas até que existam chaves suficientes para todas as rodadas.

Durante esse processo, aparecem três elementos importantes: `RotWord`, `SubWord` e `Rcon`.

O **RotWord** realiza uma rotação dos bytes de uma *word*.

O **SubWord** aplica a S-box individualmente aos quatro bytes dessa *word*.

O **Rcon** representa um conjunto de constantes utilizadas durante determinadas etapas da geração das novas chaves.

Além dessas operações, o XOR também é utilizado para combinar palavras anteriores e produzir novas palavras.

No caso do AES-128, o processo gera 44 *words* de 32 bits. Essas *words* formam onze conjuntos de 128 bits: uma chave utilizada na operação AddRoundKey inicial e outras dez chaves utilizadas nas dez rodadas.

### 1.10 Funcionamento resumido do AES-128

1. O algoritmo recebe um bloco de 128 bits e uma chave de 128 bits.
2. O bloco de entrada é organizado no State.
3. A chave original passa pelo processo de Key Expansion.
4. O State é combinado com a primeira Round Key através do AddRoundKey inicial.
5. São executadas nove rodadas contendo:
   - SubBytes;
   - ShiftRows;
   - MixColumns;
   - AddRoundKey.
6. A décima rodada executa:
   - SubBytes;
   - ShiftRows;
   - AddRoundKey.
7. O State resultante corresponde ao bloco cifrado de 128 bits.

### 1.11 Relação com a implementação do projeto

As transformações **SubBytes**, **ShiftRows**, **MixColumns** e **AddRoundKey** podem ser tratadas como blocos funcionais do núcleo AES. Além delas, também é necessário um mecanismo responsável pela expansão da chave e um controle capaz de acompanhar a rodada atual e definir quais transformações devem ser executadas.

A implementação precisa respeitar principalmente:

- a organização correta dos bytes no State;
- a ordem das transformações;
- a chave correspondente a cada rodada;
- a ausência do MixColumns na última rodada;
- o número de rodadas definido pela versão do AES utilizada.

O FIPS-197 também apresenta vetores de teste que podem ser utilizados posteriormente para verificar a implementação do algoritmo.

## 2. Serial Peripheral Interface — SPI

### 2.1 Visão geral

O **Serial Peripheral Interface (SPI)** é um protocolo de comunicação serial utilizado para realizar a troca de dados entre dispositivos digitais. É comum em sistemas que envolvem microcontroladores e periféricos, como sensores, conversores ADC e DAC, memórias e registradores.

O SPI é uma interface **síncrona e full-duplex**. Isso significa que a comunicação utiliza um sinal de clock para sincronizar a transmissão e que os dois dispositivos envolvidos podem transmitir dados ao mesmo tempo.

Na comunicação existe um dispositivo responsável por gerar o sinal de clock e controlar a transferência, chamado de **main**, enquanto o dispositivo selecionado para se comunicar com ele é chamado de **subnode**.

### 2.2 Sinais da interface SPI

Na configuração SPI de quatro fios são utilizados quatro sinais principais:

- **SCLK** — sinal de clock;
- **CS** — sinal de seleção do dispositivo;
- **MOSI** — linha de dados do main para o subnode;
- **MISO** — linha de dados do subnode para o main.

#### SCLK (*Serial Clock*)

O **SCLK** é o sinal responsável por sincronizar a transferência dos dados.

Esse sinal é gerado pelo dispositivo main. As alterações e leituras dos bits transmitidos pelas linhas de dados acontecem em relação às bordas desse clock.

Seu papel é fundamental porque o transmissor e o receptor precisam saber em qual momento o dado deve ser alterado e em qual momento ele deve ser lido.

#### CS (*Chip Select*)

O sinal **CS** é utilizado para selecionar o subnode com o qual o main deseja se comunicar.

No exemplo apresentado pela referência utilizada, esse sinal é ativo em nível baixo. Dessa forma:

- **CS = 0:** dispositivo selecionado;
- **CS = 1:** dispositivo não selecionado.

A comunicação é iniciada quando o CS é colocado em nível baixo e, ao término da transmissão, o sinal retorna para nível alto. Quando existem vários subnodes conectados ao mesmo main em uma configuração SPI convencional, cada um deles precisa possuir seu próprio sinal de seleção.

#### MOSI

**MOSI** significa *Main Out, Subnode In*.

Essa linha transporta os dados enviados pelo dispositivo main em direção ao subnode.

O sentido da comunicação pode ser representado por:

**Main → MOSI → Subnode**

#### MISO

**MISO** significa *Main In, Subnode Out*.

Essa linha realiza a comunicação no sentido contrário, transportando os dados enviados pelo subnode para o main.

O sentido da comunicação é:

**Subnode → MISO → Main**

A existência das duas linhas separadas, MOSI e MISO, permite que dados sejam transmitidos nos dois sentidos simultaneamente, caracterizando o funcionamento **full-duplex** do protocolo.

### 2.3 Funcionamento de uma transmissão SPI

Para iniciar uma comunicação, o main deve selecionar o subnode através do sinal CS e fornecer o sinal de clock.

No caso considerado pela referência, o CS é ativo em nível baixo. Portanto, o início da comunicação ocorre quando o main coloca o sinal CS em nível lógico zero.

Durante a transmissão, os dados são enviados serialmente pelas linhas MOSI e MISO. Isso significa que os bits são transmitidos um após o outro, sincronizados pelo sinal SCLK.

Em cada ciclo de comunicação existem dois eventos importantes:

- o momento em que um novo bit é colocado na linha de dados;
- o momento em que esse bit é lido pelo receptor.

Esses eventos estão relacionados às bordas de subida e descida do sinal de clock. A configuração utilizada para determinar o comportamento dessas bordas é definida pelos parâmetros **CPOL** e **CPHA**.

### 2.4 Polaridade do clock — CPOL

O parâmetro **CPOL**, ou *Clock Polarity*, determina o estado do sinal de clock quando nenhuma transferência está ocorrendo.

Existem duas possibilidades:

- **CPOL = 0:** o clock permanece em nível lógico baixo quando está em repouso;
- **CPOL = 1:** o clock permanece em nível lógico alto quando está em repouso.

Assim, o CPOL determina de qual nível o sinal SCLK partirá quando uma transmissão começar.

Quando CPOL é igual a zero, o primeiro movimento do clock ocorre do nível baixo para o nível alto.

Quando CPOL é igual a um, o primeiro movimento ocorre do nível alto para o nível baixo.

Essa diferença é importante porque altera a relação entre as bordas do clock e os eventos utilizados durante a transferência dos dados.

### 2.5 Fase do clock — CPHA

O parâmetro **CPHA**, ou *Clock Phase*, determina como as bordas do clock são utilizadas durante a transmissão.

Na prática, o CPHA define em qual borda do SCLK o dado será **amostrado**, ou seja, lido pelo receptor, e em qual borda um novo dado será deslocado para a linha.

Os dois eventos principais podem ser entendidos como:

- **Sampling:** momento em que o receptor lê o valor presente na linha;
- **Shifting:** momento em que o transmissor altera ou desloca o próximo bit para a linha.

A borda utilizada para cada evento depende da combinação entre CPOL e CPHA.

Para que a comunicação funcione corretamente, os dispositivos envolvidos precisam utilizar configurações compatíveis de polaridade e fase do clock.

### 2.6 Relação entre CPOL, CPHA e os modos SPI

Os diferentes modos de operação do SPI são definidos pela combinação entre os valores de **CPOL** e **CPHA**.

O CPOL determina o nível de repouso do sinal de clock:

- **CPOL = 0:** clock em repouso em nível baixo;
- **CPOL = 1:** clock em repouso em nível alto.

Já o CPHA está relacionado à escolha das bordas utilizadas para a amostragem e para o deslocamento dos dados.

A combinação entre esses dois parâmetros determina completamente o comportamento do clock durante a comunicação.

Esse é um dos pontos mais importantes para a implementação do protocolo, pois os dispositivos envolvidos precisam trabalhar com configurações compatíveis para interpretar corretamente os dados transmitidos. A configuração utilizada pelo main deve atender aos requisitos do subnode conectado.

### 2.7 Comunicação com múltiplos dispositivos

O SPI também permite que um único main se comunique com mais de um subnode.

Na configuração convencional, os sinais de clock e de dados podem ser compartilhados entre os dispositivos, enquanto cada subnode possui seu próprio sinal de CS.

Dessa forma, o main seleciona qual dispositivo participará da comunicação colocando apenas o sinal CS correspondente em nível ativo.

A referência também apresenta a possibilidade de utilização de dispositivos em uma configuração *daisy-chain*. Nesse caso, os dados passam sequencialmente de um dispositivo para o próximo.

Entretanto, esse tipo de conexão não é suportado por todos os dispositivos SPI e aumenta a quantidade de ciclos de clock necessária conforme aumenta a posição do dispositivo na cadeia.

### 2.8 Relação do SPI com o projeto

No projeto do acelerador AES, o SPI funciona como a interface de comunicação entre o sistema externo e o núcleo desenvolvido em RTL.

Enquanto o AES é responsável pelo processamento criptográfico, o SPI é responsável pela transferência serial dos dados utilizados pelo acelerador.

Dessa forma, a interface SPI poderá ser responsável por receber informações provenientes de um dispositivo externo e disponibilizá-las internamente para o sistema.

Do ponto de vista da implementação, será necessário identificar corretamente:

- quando o dispositivo está selecionado através do CS;
- as bordas do SCLK;
- os bits recebidos através do MOSI;
- os bits enviados através do MISO;
- o modo SPI utilizado pelo sistema.

Esses elementos servirão de base para a futura implementação da interface SPI e para sua integração com o núcleo AES.