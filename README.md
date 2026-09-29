# Acelerador AES com Interface SPI e Baixo Consumo

## 1. Visão geral

Este projeto tem como objetivo desenvolver um IP digital para executar o algoritmo de criptografia AES, controlado por um dispositivo externo através de uma interface SPI.

O sistema utilizará um banco de registradores para receber a chave criptográfica, os dados de entrada e os comandos de controle, além de disponibilizar o status e o resultado da operação.

O desenvolvimento contempla arquitetura, RTL sintetizável, simulação, síntese lógica, verificação formal e técnicas de baixo consumo com intenção de potência descrita em UPF.

O projeto está organizado em 15 semanas, com entregáveis e critérios de aceite específicos.

## 2. Objetivos

- Estudar o algoritmo AES e o protocolo SPI.
- Desenvolver o núcleo AES em RTL.
- Implementar a interface SPI e o banco de registradores.
- Realizar a integração e a verificação do sistema.
- Executar a síntese lógica e analisar área, timing e potência.
- Desenvolver propriedades para verificação formal.
- Implementar e avaliar técnicas de baixo consumo.
- Documentar os resultados do projeto.

## 3. Arquitetura de alto nível

O sistema está organizado nos seguintes blocos:

- Interface SPI: comunicação com o dispositivo externo.
- Sincronização: transferência segura entre os domínios de clock.
- Banco de registradores: armazenamento de chave, dados, controle, status e resultado.
- Núcleo AES: processamento criptográfico.
- Controlador de energia: gerenciamento dos modos de operação e energia.

Os detalhes das interfaces e da microarquitetura serão definidos na etapa de arquitetura, conforme a especificação funcional.

## 4. Estrutura do repositório

```text
.
├── README.md
├── docs/
│   ├── spec/           # Especificação funcional
│   ├── architecture/   # Arquitetura funcional e de energia
│   └── reports/        # Relatórios semanais
├── rtl/                # Código RTL
├── tb/                 # Testbenches
├── formal/             # Propriedades e scripts de verificação formal
├── syn/                # Restrições, scripts e relatórios de síntese
├── upf/                # Intenção de potência e relatórios
└── scripts/            # Automação do fluxo de desenvolvimento
```

## 5. Planejamento

As atividades são gerenciadas por meio do GitHub Issues e do GitHub Projects.

Cada entrega será identificada por uma tag ou branch correspondente à semana.

## 6. Ambiente de desenvolvimento

A configuração das ferramentas de simulação, lint e síntese será documentada após a disponibilização dos recursos pelo instrutor.

O fluxo mínimo de compilação, lint e simulação será automatizado durante a primeira semana.

## 7. Referências

- NIST FIPS-197 — Advanced Encryption Standard (AES).
- Documento do projeto Hands-on — RTL Design Track: Acelerador AES com interface SPI e baixo consumo.

## 8. Estado atual

Semana 1 — Kick-off, estudo e preparação do ambiente.

A implementação do RTL ainda não foi iniciada.