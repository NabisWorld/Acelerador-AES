# Relatório — Semana 2
## 1. Objetivo
Tive como objetivo dessa semana a implementação e verificação de três módulos combinacionais

- **S-box:**
- **SubBytes:** 
- **ShiftRows:**

## 2. Implementações realizadas
As implementações foram desenvolvidas em SystemVerilog, utilizando a FIPS-197 como referência para o funcionamento das operações.

### 2.1. Módulo S-box

**Arquivo:** `rtl/minisoc_aes/minisoc_aes_sbox.sv`

Foi implementado um módulo combinacional com entrada e saída de 8 bits.

A implementação utiliza uma tabela de substituição organizada em 16 linhas de 128 bits, selecionadas por meio de uma estrutura `case`.

Os quatro bits mais significativos da entrada selecionam a linha da tabela, enquanto os quatro bits menos significativos determinam o byte correspondente.

### 2.2. Módulo SubBytes

**Arquivo:** `rtl/minisoc_aes/minisoc_aes_sub_bytes.sv`

Foi implementado um módulo combinacional com entrada e saída de 128 bits.

O módulo utiliza 16 instâncias da S-box, sendo cada uma responsável por substituir um dos 16 bytes do estado AES.

As instâncias funcionam em paralelo, permitindo realizar as substituições sem a utilização de clock ou registradores.

### 2.3. Módulo ShiftRows

**Arquivo:** `rtl/minisoc_aes/minisoc_aes_shift_rows.sv`

Foi implementado um módulo combinacional responsável pelos deslocamentos circulares das quatro linhas do estado AES.

Os deslocamentos realizados são:

- Linha 0: nenhum deslocamento.
- Linha 1: deslocamento circular de 1 byte para a esquerda.
- Linha 2: deslocamento circular de 2 bytes para a esquerda.
- Linha 3: deslocamento circular de 3 bytes para a esquerda.

A implementação utiliza instruções `assign` para reorganizar os bytes, sem modificar seus valores.

## 3. Metodologia de verificação

Foram desenvolvidos testbenches autoverificáveis para os três módulos.

Os testes foram executados utilizando Icarus Verilog, enquanto as análises de lint foram realizadas com Verilator (apenas para testes iniciais por questoes de problemas envolvendo a chave publica, impossibilitando o uso das ferramentas da synopsys)

### 3.1. Verificação da S-box

**Testbench:** `tb/minisoc_aes_sbox_tb.sv`

Foi utilizado um laço `for` para percorrer automaticamente todas as 256 entradas possíveis da S-box.

Os resultados produzidos foram comparados com uma tabela de referência baseada na FIPS-197, armazenada no arquivo:

`tb/vectors/aes_sbox_ref.hex`

A tabela foi carregada no testbench utilizando a instrução `$readmemh`.

**Resultado:** PASS — todas as 256 entradas foram verificadas com sucesso.

### 3.2. Verificação do SubBytes

**Testbench:** `tb/minisoc_aes_sub_bytes_tb.sv`

Foram executados três testes funcionais:

1. Substituição dos 16 bytes de um estado de entrada conhecido.
2. Verificação da operação SubBytes da rodada 1 do Apêndice B da FIPS-197.
3. Verificação da operação SubBytes da rodada 10 do Apêndice B da FIPS-197.

As saídas de 128 bits foram comparadas automaticamente com os respectivos resultados esperados.

**Resultado:** PASS — os três testes foram aprovados.

### 3.3. Verificação do ShiftRows

**Testbench:** `tb/minisoc_aes_shift_rows_tb.sv`

Foram executados três testes funcionais:

1. Reorganização de um estado contendo os bytes de `00` até `0F`.
2. Verificação da operação ShiftRows da rodada 1 do Apêndice B da FIPS-197.
3. Verificação da operação ShiftRows da rodada 10 do Apêndice B da FIPS-197.

**Resultado:** PASS — os três testes foram aprovados.

## 4. Análise de lint

Os módulos S-box, SubBytes e ShiftRows foram analisados individualmente utilizando o Verilator com as opções `--lint-only -Wall`.

Após a correção dos avisos de formatação encontrados durante o desenvolvimento, os três módulos passaram na análise sem erros ou avisos.

## 5. Automação dos testes

O Makefile do projeto foi atualizado para permitir a execução dos testes da Semana 2 por meio de um único comando:

```bash
make semana2
```

Esse comando executa os três testbenches utilizando Icarus Verilog e realiza o lint dos módulos com Verilator.

O fluxo original com ferramentas Synopsys foi preservado, com uma opção separada para executar os testes com Vlogan e VCS. Essa opção ainda não foi validada no ambiente Synopsys.

## 6. Resultados obtidos

| Módulo | Verificação funcional | Lint |
|---|---|---|
| S-box | PASS — 256 entradas | PASS |
| SubBytes | PASS — 3 testes | PASS |
| ShiftRows | PASS — 3 testes | PASS |

A execução automatizada apresentou a mensagem:

`PASS: SEMANA 2 - TESTES E LINT APROVADOS!`

**Organização do Makefile**

O Makefile inicial utilizava Vlogan e VCS e fazia referência a um testbench unificado da Semana 2.

O arquivo foi adaptado para executar os três testbenches individuais desenvolvidos, mantendo o fluxo Synopsys e acrescentando a possibilidade de verificação com Icarus e Verilator.

## 7. Conclusão

Durante a Semana 2, foram implementados os módulos combinacionais S-box, SubBytes e ShiftRows do algoritmo AES-128.

Os três módulos apresentaram os resultados esperados nos testes funcionais realizados e foram aprovados na análise de lint.

Também foi configurada a execução automatizada dos testes por meio do Makefile, permitindo verificar os módulos com um único comando.

Dessa forma, a etapa de implementação e verificação funcional prevista para a Semana 2 foi concluída no ambiente Codespaces.