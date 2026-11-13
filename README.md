# Acelerador AES com Interface SPI e Baixo Consumo

Este projeto tem como objetivo desenvolver um acelerador criptográfico em **SystemVerilog**, baseado no padrão **AES-128**, com interface **SPI** para comunicação e controle.

O desenvolvimento segue uma abordagem modular e incremental, com foco na implementação do hardware, na verificação funcional e na preparação para futuras estratégias de baixo consumo.

## Objetivos

- Implementar as operações de cifragem e decifragem do AES-128.
- Integrar processamento criptográfico, controle e comunicação SPI.
- Verificar os componentes por meio de simulações e testes unitários.
- Preparar a arquitetura para futuras otimizações de consumo de energia.

## Visão geral da arquitetura

O sistema é planejado em torno de um **núcleo AES**, responsável pelo processamento criptográfico, e de uma **interface SPI**, utilizada para configuração e controle. A arquitetura também prevê lógica de controle, memória compartilhada e gerenciamento de clock e reset.

Para o núcleo AES-128, foi escolhida uma abordagem **iterativa**, que reutiliza os recursos de processamento ao longo das rodadas do algoritmo.

## Andamento do projeto

O trabalho é realizado em etapas. Já foram desenvolvidos componentes das transformações diretas e inversas do AES e definida a microarquitetura proposta.

A implementação do *datapath* e da expansão de chave está em andamento, juntamente com os testes unitários. A integração completa do acelerador, da interface SPI e das funcionalidades de baixo consumo faz parte das próximas etapas.

> **Status:** em desenvolvimento. A presença de módulos e testes no repositório não significa que o sistema completo já tenha sido validado.

## Tecnologias e ferramentas

- **Linguagem:** SystemVerilog
- **Simulação:** Icarus Verilog e Synopsys VCS
- **Análise de código:** Verilator e Synopsys Vlogan
- **Automação:** GNU Make

## Execução dos testes

O `Makefile` disponibiliza fluxos de teste para diferentes etapas do desenvolvimento:

```bash
make semana1
make semana2
make semana3-synopsys
make semana4-synopsys
```

Os comandos dependem das ferramentas instaladas e disponíveis no ambiente. A execução da terceira etapa requer ferramentas Synopsys. Os testes devem ser executados para confirmar a situação atual da implementação.
