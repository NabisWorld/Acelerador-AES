# Acelerador AES com Interface SPI e Baixo Consumo

## 1. Visão Geral

Este projeto tem como objetivo desenvolver um acelerador AES em RTL com interface SPI e suporte futuro a técnicas de baixo consumo.

A arquitetura do sistema prevê, entre outros blocos, o núcleo AES, interface SPI, banco de registradores, geração de clock, reset e interface com memória.

O desenvolvimento será realizado de forma incremental ao longo das etapas do projeto.

---

## 2. Arquitetura de Alto Nível

O sistema utiliza a arquitetura **AES Top-Level System**, compartilhada entre as trilhas de RTL Design e Design Verification.

As principais interfaces externas são:

- `GLOBAL RESET`
- `clk from OSC`
- `SPI IF`
- `MEMORY DATA IF`

Os principais blocos previstos são:

### RESET

Responsável pelo controle e distribuição da sequência de reset do sistema.

### PLL

Responsável pela geração do clock do sistema a partir do clock externo.

Durante as etapas iniciais será utilizado um modelo comportamental simples. O sinal `locked` será utilizado para indicar que o PLL atingiu uma condição válida de operação.

### SPI

Responsável pela comunicação de configuração e controle do sistema.

A lógica de recepção e transmissão SPI opera no domínio do `SCLK`.

### Banco de Registradores

Responsável pelo armazenamento das informações de configuração, controle e status do sistema.

### Núcleo AES

Responsável pela execução das operações criptográficas definidas pelo padrão AES.

### MEMORY / DATA System

Responsável pela interface entre os dados externos, a memória e o núcleo AES.

### Memória

Responsável pelo armazenamento dos dados utilizados pelo sistema.

Durante as etapas iniciais será utilizado um modelo comportamental simples.

### Controlador de Energia

Será introduzido posteriormente para gerenciar os modos de baixo consumo, incluindo isolamento, retenção, desligamento e religamento de blocos.

A arquitetura possui pelo menos dois domínios de clock relevantes:

- domínio do `SCLK`, utilizado pela interface SPI;
- domínio do sistema, gerado pelo PLL.

A estratégia de sincronização entre esses domínios será definida durante o desenvolvimento da arquitetura e microarquitetura.

---

## 3. Estrutura do Repositório

A estrutura inicial do projeto foi organizada da seguinte forma:

```text
.
├── docs/
│   ├── architecture/
│   ├── reports/
│   └── spec/
├── formal/
├── models/
├── rtl/
├── scripts/
├── syn/
├── tb/
├── upf/
├── Makefile
└── README.md
```

Os principais diretórios possuem as seguintes funções:

- `rtl/`: módulos RTL sintetizáveis;
- `tb/`: testbenches utilizados durante a simulação;
- `docs/`: documentação, especificações e relatórios;
- `models/`: modelos comportamentais utilizados durante a verificação;
- `scripts/`: scripts auxiliares do fluxo;
- `syn/`: arquivos relacionados à síntese lógica;
- `formal/`: arquivos relacionados à verificação formal;
- `upf/`: arquivos relacionados à intenção de potência.

---

## 4. Ambiente Mínimo — Semana 1

Durante a primeira semana foi preparado um ambiente mínimo para validar o fluxo de desenvolvimento RTL.

Para essa validação foram criados:

```text
rtl/porta_and.sv
tb/porta_and_tb.sv
Makefile
```

O módulo `porta_and.sv` é utilizado apenas como um exemplo RTL simples para verificar o funcionamento das ferramentas e dos scripts de execução.

O testbench `porta_and_tb.sv` testa as quatro combinações possíveis das entradas da porta AND e verifica automaticamente os resultados obtidos.

O fluxo definido no Makefile é:

```text
check
  ↓
syntax + lint
  ↓
compile
  ↓
run
```

A análise e o lint são realizados com `vlogan`, utilizando a opção `+lint=all`.

A compilação e elaboração são realizadas pelo Synopsys VCS, que gera o executável de simulação `simv`.

---

## 5. Requisitos do Ambiente

Para executar o fluxo mínimo são necessários:

- GNU Make;
- Synopsys VCS;
- Synopsys Vlogan.

As ferramentas Synopsys precisam estar instaladas, licenciadas e disponíveis no `PATH` do ambiente.

É possível verificar a disponibilidade utilizando:

```bash
command -v vlogan
command -v vcs
```

---

## 6. Execução

O fluxo completo da Semana 1 foi preparado para ser executado através de um único comando:

```bash
make
```

Também é possível executar individualmente cada etapa:

```bash
make check
make syntax
make compile
make run
make clean
```

Onde:

- `make check`: verifica a disponibilidade das ferramentas e dos arquivos;
- `make syntax`: realiza a análise SystemVerilog e o lint;
- `make compile`: realiza a compilação e elaboração;
- `make run`: executa a simulação;
- `make clean`: remove os artefatos gerados pelas ferramentas.

---
