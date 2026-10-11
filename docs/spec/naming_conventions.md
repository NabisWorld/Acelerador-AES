# Convenções de Nomenclatura RTL

Este documento define o padrão de nomenclatura utilizado no desenvolvimento RTL do Acelerador AES.

O objetivo é manter consistência entre módulos, sinais, testbenches e demais componentes do projeto.

## 1. Padrão geral

Nomes de arquivos, módulos e sinais devem utilizar `snake_case`.

Exemplos:

- `aes_core`
- `spi_slave`
- `register_bank`
- `round_counter`

Evitar:

- `AESCore`
- `aesCore`
- `AES_CORE`

## 2. Arquivos RTL

Os arquivos SystemVerilog devem utilizar a extensão `.sv` e possuir o mesmo nome do módulo principal.

Exemplo:

```text
aes_core.sv
```

```systemverilog
module aes_core;

endmodule
```

## 3. Entradas e saídas

Entradas devem utilizar o sufixo `_i`.

Saídas devem utilizar o sufixo `_o`.

Exemplo:

```systemverilog
input  logic         start_i;
input  logic [127:0] plaintext_i;

output logic         done_o;
output logic [127:0] ciphertext_o;
```

## 4. Clocks

Sinais de clock devem utilizar o prefixo `clk_`.

Exemplos:

```text
clk_sys
clk_spi
clk_aes
```

Quando o clock for uma entrada de um módulo, também deve utilizar o sufixo `_i`.

Exemplo:

```systemverilog
input logic clk_sys_i;
```

## 5. Reset

Sinais de reset devem utilizar o prefixo `rst_`.

Resets ativos em nível baixo devem utilizar o sufixo `_n`.

Exemplos:

```text
rst_sys_n
rst_spi_n
```

Quando o reset for uma entrada de um módulo:

```systemverilog
input logic rst_n_i;
```

## 6. Sinais de habilitação

Sinais de habilitação devem utilizar o sufixo `_en`.

Exemplos:

```text
aes_en
round_en
key_load_en
write_en
read_en
```

## 7. Sinais de controle

Os sinais de controle devem possuir nomes que indiquem claramente sua função.

Exemplos:

```text
start
busy
done
valid
ready
```

Evitar nomes genéricos como:

```text
flag
ctrl
temp
aux
signal
```

## 8. Sinais registrados

Quando for necessário diferenciar o valor atual de um registrador e o próximo valor a ser armazenado, utilizar:

- `_q` para o valor atualmente registrado;
- `_d` para o próximo valor.

Exemplo:

```systemverilog
logic [127:0] state_q;
logic [127:0] state_d;
```

Outro exemplo:

```systemverilog
logic [3:0] round_count_q;
logic [3:0] round_count_d;
```

## 9. Máquinas de estado

Os estados de máquinas de estados finitas devem utilizar letras maiúsculas.

Exemplo:

```systemverilog
typedef enum logic [2:0] {
    IDLE,
    LOAD,
    ROUND,
    FINAL_ROUND,
    DONE
} state_t;
```

As variáveis utilizadas para armazenar os estados devem seguir o padrão `_q` e `_d`.

Exemplo:

```systemverilog
state_t state_q;
state_t state_d;
```

## 10. Parâmetros e constantes

Parâmetros, constantes e `localparam` devem utilizar letras maiúsculas, com palavras separadas por `_`.

Exemplos:

```systemverilog
parameter int DATA_WIDTH = 128;
parameter int KEY_WIDTH  = 128;
parameter int NUM_ROUNDS = 10;

localparam int BYTE_WIDTH = 8;
```

## 11. Sinais internos

Sinais internos dos módulos não devem utilizar os sufixos `_i` e `_o`.

Esses sufixos são reservados para portas de entrada e saída.

Exemplo:

```systemverilog
logic [127:0] round_key;
logic [127:0] state_q;
logic [127:0] state_d;

logic [3:0] round_count;
logic       round_done;
```

## 12. Dados válidos e handshake

Sinais que indicam a validade de um dado devem utilizar o sufixo `_valid`.

Exemplos:

```text
data_valid
spi_rx_valid
aes_output_valid
```

Sinais que indicam que um módulo está pronto para receber ou processar dados devem utilizar o sufixo `_ready`.

Exemplos:

```text
data_ready
spi_rx_ready
aes_ready
```

## 13. Exemplo de interface RTL

Exemplo de aplicação das convenções em um possível módulo `aes_core`:

```systemverilog
module aes_core (
    input  logic         clk_i,
    input  logic         rst_n_i,

    input  logic         start_i,
    input  logic [127:0] key_i,
    input  logic [127:0] plaintext_i,

    output logic [127:0] ciphertext_o,
    output logic         busy_o,
    output logic         done_o
);

endmodule
```

Essa interface é apenas um exemplo de aplicação das convenções de nomenclatura. A interface definitiva do núcleo AES será definida durante o desenvolvimento da arquitetura.