# Relatório — Semana 4
## 1. Objetivo
Tive como objetivo dessa semana a implementação e verificação dos módulos responsáveis pela expansão da chave e pelo processamento completo de um bloco AES-128, contemplando as operações de cifragem e decriptação.

- `minisoc_aes_key_exp`, responsável pela geração das 11 chaves de rodada do AES-128.
- `minisoc_aes_dp`, responsável pela cifragem e decriptação de blocos de 128 bits.
- testbenches utilizando os vetores de referência da FIPS-197.
- Análise de lint e automação dos testes pelo Makefile.

## 2. Implementações realizadas

### 2.1. Módulo Key Expansion

**Arquivo:** `rtl/minisoc_aes/minisoc_aes_key_exp.sv`

Esse é o modulo responsável pela expansão da chave AES-128, a estratégia de pré-computação sequencial definida anteriormente na microarquitetura.

O módulo recebe uma chave original de 128 bits e gera 11 chaves de rodada, identificadas de K0 a K10.

A primeira chave, K0, corresponde à chave original. As outras dez são calculadas sucessivamente, utilizando as operações estabelecidas na FIPS-197:

- **RotWord:** rotação circular dos quatro bytes da última palavra da chave anterior.
- **SubWord:** substituição dos quatro bytes por meio da S-box do AES.
- **Rcon:** aplicação da constante correspondente à rodada.
- **XOR:** combinação das palavras anteriores para gerar as quatro palavras da nova chave.

Cada nova chave de 128 bits é calculada e registrada em um ciclo de geração (são necessários dez ciclos para gerar K1 até K10).

As chaves são armazenadas em um banco interno de 11 posições de 128 bits, totalizando 1.408 bits.

A interface disponibiliza sinais para iniciar a expansão, acompanhar o processamento, indicar a conclusão e selecionar a chave desejada.

### 2.2. Justificativa da expansão pré-computada

A estratégia pré-computada foi escolhida em vez da geração *on-the-fly* por facilitar o acesso às chaves durante a cifragem e, principalmente, durante a decriptação.

Na cifragem, as chaves são utilizadas na ordem K0 até K10. Na decriptação convencional, a ordem é inversa, começando em K10 e terminando em K0.

O armazenamento das 11 chaves permite realizar essas operações sem recalcular a expansão durante cada rodada.

Essa abordagem apresenta como vantagens a simplificação da seleção das chaves e a possibilidade de reutilizá-las durante o processamento de múltiplos blocos.

Como desvantagens, exige armazenamento adicional de 1.408 bits e introduz dez ciclos de preparação antes da utilização das chaves.

### 2.3. Módulo Datapath AES-128

**Arquivo:** `rtl/minisoc_aes/minisoc_aes_dp.sv`

Datapath responsável por executar a cifragem e a decriptação de um bloco de 128 bits.

O módulo integra as transformações desenvolvidas nas semanas anteriores.

**Cifragem:**
- SubBytes
- ShiftRows
- MixColumns
- AddRoundKey

**Decriptação:**
- InvShiftRows
- InvSubBytes
- InvMixColumns
- AddRoundKey

A operação AddRoundKey é compartilhada entre os dois sentidos de processamento.

Na cifragem, as nove rodadas intermediárias executam SubBytes, ShiftRows, MixColumns e AddRoundKey. A rodada final não utiliza MixColumns.

Na decriptação, são utilizadas as transformações inversas e as chaves em ordem decrescente. A etapa final não utiliza InvMixColumns.

### 2.4. Controle por máquina de estados

O controle interno do datapath foi implementado por uma máquina de estados finitos (FSM), conforme a microarquitetura definida na Semana 3.

A FSM possui cinco estados:

| Estado | Responsabilidade |
|---|---|
| `ST_IDLE` | Aguarda uma solicitação válida de processamento |
| `ST_INIT` | Executa o AddRoundKey inicial |
| `ST_ROUND` | Executa as nove rodadas intermediárias |
| `ST_FINAL_ROUND` | Executa a última rodada |
| `ST_DONE` | Sinaliza a conclusão do processamento |

O datapath utiliza um registrador de 128 bits para armazenar o estado intermediário e um contador de rodadas para controlar a sequência das transformações.

A seleção das chaves é realizada por meio de `round_sel_o`, conectado ao módulo de expansão.

O processamento de um bloco é iniciado apenas quando as chaves estão disponíveis. Ao final, o módulo disponibiliza o bloco resultante e gera um pulso de conclusão.

O datapath implementado corresponde ao *primitive* AES-128 de um bloco. Os modos ECB, CBC, PCBC, CFB, OFB e CTR e o processamento de múltiplos blocos pertencem à integração posterior com o controlador `minisoc_aes_top`.

## 3. Metodologia de verificação

Foram desenvolvidos dois testbenches autoverificáveis, responsáveis por comparar os resultados calculados com valores esperados.

Os testes utilizaram a FIPS-197 como referência para a expansão das chaves e para as operações de cifragem e decriptação.

### 3.1. Verificação do Key Expansion

**Testbench:** `tb/minisoc_aes_key_exp_tb.sv`

Foram utilizadas duas chaves de referência, correspondentes aos exemplos da FIPS-197.

Para cada chave, foram verificadas as 11 round keys em ordem direta e inversa.

Também foram realizados testes de controle para verificar o início da expansão, o período de processamento, o pulso de conclusão, a validade das chaves, a rejeição de novas solicitações durante a operação e o comportamento após reset.

O testbench também verifica que a seleção de um índice de rodada inválido não disponibiliza uma chave.

**Resultado:** PASS — as 11 round keys foram verificadas com sucesso para os dois conjuntos de referência. Os testes adicionais de controle e reset também foram aprovados.

### 3.2. Verificação do Datapath

**Testbench:** `tb/minisoc_aes_dp_tb.sv`

O testbench integra os módulos Key Expansion e Datapath, conectando a seleção de rodada à saída da chave correspondente.

Foram executados quatro testes principais, utilizando os vetores dos Apêndices B e C.1 da FIPS-197.

O testbench verifica a cifragem de cada chave e a decriptação de cada chave, comparando automaticamente as saídas com os valores esperados.

Também foram verificadas a sequência das chaves de rodada, a rejeição de `start` sem chaves válidas, o controle de conclusão e a interrupção de uma operação por reset.

### 3.3. Resultados dos testes funcionais

| Teste | Resultado esperado | Status |
|---|---|---|
| Cifragem C.1 | `69c4e0d86a7b0430d8cdb78070b4c55a` | PASS |
| Decriptação C.1 | `00112233445566778899aabbccddeeff` | PASS |
| Cifragem B | `3925841d02dc09fbdc118597196a0b32` | PASS |
| Decriptação B | `3243f6a8885a308d313198a2e0370734` | PASS |

Todos os quatro testes principais apresentaram correspondência exata entre os resultados calculados pelo datapath e os vetores de referência.

A simulação também apresentou as mensagens:

```text
PASS: start ignorado quando keys_valid=0
PASS: C.1 encrypt
PASS: C.1 decrypt
PASS: B encrypt
PASS: B decrypt
PASS: reset interrompeu a operacao
PASS: Datapath AES-128 - todos os testes!
```

**Resultado:** PASS — cifragem, decriptação e verificações adicionais de controle aprovadas nos cenários executados.

## 4. Análise de lint

A análise foi realizada utilizando o Synopsys Vlogan com a opção `+lint=all` e configuração de tempo `1ns/1ps`.

Durante a execução automatizada, não foram reportados erros de compilação ou avisos de lint nos módulos RTL analisados.

Foram identificados 28 avisos do tipo:

`Lint-[NS] Null statement`

Esses avisos apareceram exclusivamente nos testbenches:

| Arquivo | Quantidade de avisos |
|---|---:|
| `minisoc_aes_key_exp_tb.sv` | 12 |
| `minisoc_aes_dp_tb.sv` | 16 |
| **Total** | **28** |

Os avisos estão relacionados a construções utilizadas no ambiente de simulação, como instruções de atraso com comando vazio.

Não foram identificados avisos desse tipo nos módulos RTL sintetizáveis.

As simulações foram concluídas normalmente, sem falhas nos testes funcionais.

**Resultado:** análise Vlogan concluída sem erros. Permaneceram 28 avisos `Lint-[NS]` nos testbenches, sem impacto observado nos testes executados.

Essa verificação corresponde ao lint disponibilizado pelo Vlogan, não a uma execução de análise estática dedicada com SpyGlass.

## 5. Automação dos testes

O Makefile do projeto foi atualizado para incluir os módulos e testbenches desenvolvidos na Semana 4.

Foi criado o alvo:

```bash
make semana4-synopsys
```

Esse comando executa automaticamente:

1. Verificação da disponibilidade do Vlogan e VCS.
2. Verificação da existência dos arquivos necessários.
3. Análise dos arquivos SystemVerilog com Vlogan.
4. Compilação e simulação do Key Expansion com VCS.
5. Compilação e simulação do Datapath com VCS.

Após os testes individuais, a regressão automatizada foi executada novamente no servidor.

**Resultado:** PASS — regressão automatizada concluída com sucesso em 12/11/2026.

## 6. Resultados obtidos

| Entregável | Implementação | Verificação |
|---|---|---|
| `minisoc_aes_key_exp.sv` | Concluída | PASS |
| `minisoc_aes_dp.sv` | Concluída | PASS |
| `minisoc_aes_key_exp_tb.sv` | Concluído | PASS |
| `minisoc_aes_dp_tb.sv` | Concluído | PASS |
| Automação no Makefile | Concluída | PASS |
| Análise Vlogan com `+lint=all` | Executada | Sem erros; avisos nos testbenches |

Os módulos implementados permitiram realizar a expansão das chaves e o processamento completo de blocos AES-128 nos dois sentidos.

A integração direta entre Key Expansion e Datapath foi verificada com os vetores fornecidos para a Semana 4.

O funcionamento do sistema completo, envolvendo SPI, memória compartilhada, processamento de múltiplos blocos e modos de operação, não fez parte da verificação desta etapa.

