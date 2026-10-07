# Acelerador AES com Interface SPI e Baixo Consumo

## 1. Visão Geral

Este projeto tem como objetivo desenvolver um sistema digital de topo
(**AES Top-Level System**) contendo um datapath AES, seguindo a mesma
arquitetura utilizada no projeto integrador da trilha de Design Verification.

O sistema será configurado e controlado por uma interface SPI, receberá e
devolverá dados através de uma interface de dados com memória e contará com
blocos dedicados de reset e geração de clock.

O desenvolvimento contempla o fluxo de projeto de um IP digital, incluindo:

- definição de arquitetura e microarquitetura;
- desenvolvimento de RTL sintetizável;
- integração de diferentes domínios de clock;
- simulação e lint;
- síntese lógica;
- verificação de equivalência entre RTL e netlist utilizando Formality;
- descrição da intenção de potência através de UPF;
- aplicação e avaliação de técnicas de baixo consumo.

O projeto possui duração prevista de 15 semanas, com entregas semanais e
critérios de aceite definidos pelo instrutor. 
---

## 2. Objetivos

Os principais objetivos do projeto são:

- estudar o algoritmo AES e o protocolo SPI;
- compreender e implementar a arquitetura AES Top-Level System;
- desenvolver o núcleo AES em RTL;
- implementar a interface SPI e o banco de registradores;
- implementar o bloco de reset;
- integrar a geração de clock do sistema;
- desenvolver modelos comportamentais do PLL e da memória para os testes iniciais;
- implementar o subsistema MEMORY / DATA;
- integrar todos os blocos no top-level do sistema;
- tratar corretamente a comunicação entre diferentes domínios de clock;
- preparar restrições de timing e executar síntese lógica;
- analisar área, timing e potência;
- verificar equivalência entre RTL e netlist utilizando Formality;
- descrever a arquitetura de energia utilizando UPF;
- aplicar técnicas de baixo consumo, como clock gating, power gating,
  isolamento e retenção;
- documentar tecnicamente as decisões e resultados do projeto.

Esses objetivos seguem diretamente o escopo definido para a trilha RTL. 

---

## 3. Arquitetura de Alto Nível

O sistema utiliza a arquitetura **AES Top-Level System**, compartilhada entre
as trilhas de RTL Design e Design Verification.

As principais interfaces externas são:

- `GLOBAL RESET`
- `clk from OSC`
- `SPI IF`
- `MEMORY DATA IF`

Os principais blocos do sistema são:

### RESET

Responsável pelo controle e distribuição da sequência de reset do sistema.

### PLL

Responsável pela geração do clock do sistema a partir do clock externo.
Durante as etapas iniciais será utilizado um modelo comportamental simples.

O sistema utiliza o sinal `locked` para indicar que o PLL atingiu uma condição
válida de operação.

### SPI

Responsável pela configuração e pelo controle do sistema.

A lógica de recepção e transmissão SPI opera no domínio do `SCLK`.

### Banco de Registradores

Responsável por armazenar informações de configuração, controle e status do
sistema, incluindo os bits de configuração do PLL.

### Núcleo AES

Responsável pela execução das operações criptográficas definidas pelo padrão AES.

### MEMORY / DATA System

Responsável pela interface entre os dados externos, a memória e o núcleo AES.

### Memória

Responsável pelo armazenamento dos dados utilizados pelo sistema.
Durante as etapas iniciais será utilizado um modelo comportamental simples.

### Controlador de Energia

Será introduzido posteriormente para gerenciar os modos de baixo consumo,
incluindo sequências de desligamento, religamento, isolamento e retenção.

A arquitetura possui pelo menos dois domínios de clock relevantes:

- domínio do `SCLK`, utilizado pela interface SPI;
- domínio do sistema, gerado pelo PLL.

A estratégia de sincronização entre esses domínios será definida durante a
etapa de arquitetura e microarquitetura.

---

## 4. Fluxo Geral do Sistema

De forma simplificada, o sistema seguirá o seguinte fluxo:

```text
                    AES TOP-LEVEL SYSTEM

 GLOBAL RESET ────────► RESET ─────────────────────┐
                                                     │
 clk from OSC ────────► PLL ─────► system clock ────┤
                                                     ▼
 SPI IF ◄─────────────► SPI ───────────────────────► AES ◄────► MEMORY
                         │                            ▲             ▲
                         │                            │             │
                         └──── configuração ──────────┘             │
                                                                   │
 MEMORY DATA IF ◄────► MEMORY / DATA SYSTEM ───────────────────────┘
