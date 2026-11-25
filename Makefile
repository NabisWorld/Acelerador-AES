
# ==============================================================================
# Makefile - MiniSoC AES | Trilha RTL Design
#
# Semana 1: Porta AND - Synopsys
# Semana 2: S-box, SubBytes e ShiftRows
# Semana 3: MixColumns, AddRoundKey e transformacoes inversas
# Semana 4: Key Expansion e Datapath AES-128
#
# Comandos:
#   make semana1             Semana 1 com Synopsys
#   make semana2             Semana 2 com Vlogan + VCS
#   make semana3-synopsys    Semana 3 com Vlogan + VCS
#   make semana4-synopsys    Semana 4 com Vlogan + VCS
#   make semana5-synopsys    Semana 5 com Vlogan + VCS
#   make WEEK=2 syntax       Analise com Vlogan
#   make clean               Limpeza dos arquivos gerados
# ==============================================================================

# Diretorios
RTL_DIR := rtl
TB_DIR  := tb
AES_DIR := $(RTL_DIR)/minisoc_aes

# Semana selecionada (padrao: Semana 1)
WEEK ?= 1

# Arquivos RTL da Semana 2
SBOX  := $(AES_DIR)/minisoc_aes_sbox.sv
SUB   := $(AES_DIR)/minisoc_aes_sub_bytes.sv
SHIFT := $(AES_DIR)/minisoc_aes_shift_rows.sv

# Testbenches da Semana 2
TB_SBOX  := $(TB_DIR)/minisoc_aes_sbox_tb.sv
TB_SUB   := $(TB_DIR)/minisoc_aes_sub_bytes_tb.sv
TB_SHIFT := $(TB_DIR)/minisoc_aes_shift_rows_tb.sv

# Tabela de referencia da FIPS-197
SBOX_REF := $(TB_DIR)/vectors/aes_sbox_ref.hex

# Arquivos conforme a semana selecionada
ifeq ($(WEEK),1)

RTL_FILES := $(RTL_DIR)/porta_and.sv
TB_FILES  := $(TB_DIR)/porta_and_tb.sv
TOP       := porta_and_tb

else ifeq ($(WEEK),2)

RTL_FILES := $(SBOX) $(SUB) $(SHIFT)
TB_FILES  := $(TB_SBOX) $(TB_SUB) $(TB_SHIFT)

else
$(error WEEK=$(WEEK) invalida; use WEEK=1 ou WEEK=2)
endif

# Ferramentas Synopsys
TIMESCALE := 1ns/1ps

VLOGAN_FLAGS := -full64 -sverilog -kdb +lint=all -timescale=$(TIMESCALE)

VCS_FLAGS := -full64 \
             -timescale=$(TIMESCALE) \
             -debug_access+all \
             -kdb

.DEFAULT_GOAL := all

# Fluxo padrao: Synopsys, Semana 1
all: run

# ==============================================================================
# FLUXO SYNOPSYS
# ==============================================================================

check:
	@echo "==> Verificando ambiente Synopsys..."
	@command -v vlogan >/dev/null 2>&1 || { echo "ERRO: vlogan nao encontrado"; exit 1; }
	@command -v vcs >/dev/null 2>&1 || { echo "ERRO: vcs nao encontrado"; exit 1; }
	@set -e; for file in $(RTL_FILES) $(TB_FILES); do \
		test -f "$$file" || { echo "ERRO: $$file nao encontrado"; exit 1; }; \
	done
	@echo "==> Ambiente OK."

syntax: check
	@echo "==> Analisando SystemVerilog com Vlogan..."
	vlogan $(VLOGAN_FLAGS) $(RTL_FILES) $(TB_FILES)

compile: syntax
ifeq ($(WEEK),1)
	vcs $(VCS_FLAGS) -top $(TOP) -o simv
else
	vcs $(VCS_FLAGS) -top minisoc_aes_sbox_tb -o simv_sbox_vcs
	vcs $(VCS_FLAGS) -top minisoc_aes_sub_bytes_tb -o simv_sub_bytes_vcs
	vcs $(VCS_FLAGS) -top minisoc_aes_shift_rows_tb -o simv_shift_rows_vcs
endif

run: compile
ifeq ($(WEEK),1)
	./simv
else
	@test -f $(SBOX_REF) || { echo "ERRO: tabela de referencia ausente"; exit 1; }
	./simv_sbox_vcs
	./simv_sub_bytes_vcs
	./simv_shift_rows_vcs
	@echo "PASS: Semana 2 - Testes Synopsys concluidos!"
endif

semana1:
	@$(MAKE) WEEK=1 run

semana2:
	@$(MAKE) WEEK=2 run

# ==============================================================================
# LIMPEZA E AJUDA
# ==============================================================================

clean:
	@echo "==> Removendo arquivos temporarios..."
	rm -rf csrc simv simv.daidir simv_* \
		AN.DB ucli.key novas* verdiLog \
		DVEfiles .vlogan* vc_hdrs.h *.log
	@echo "==> Limpeza concluida."

help:
	@echo "MiniSoC AES - Trilha RTL Design"
	@echo "  make semana1            Semana 1 - Synopsys"
	@echo "  make semana2            Semana 2 - Synopsys"
	@echo "  make semana3-synopsys   Semana 3 - Synopsys"
	@echo "  make semana4-synopsys   Semana 4 - Synopsys"
	@echo "  make semana5-synopsys   Semana 5 - Synopsys"
	@echo "  make WEEK=2 syntax      Analise com Vlogan"
	@echo "  make clean              Limpa arquivos temporarios"

.PHONY: all check syntax compile run semana1 \
        semana2 semana2-synopsys \
        clean help semana3-synopsys semana4-synopsys

# ==============================================================================
# SEMANA 3 - REGRESSAO SYNOPSYS (VLOGAN + VCS)
# ==============================================================================

.PHONY: semana3-synopsys
semana3-synopsys:
	@echo "==> Semana 3: verificando ferramentas Synopsys..."
	@command -v vlogan >/dev/null 2>&1 || { echo "ERRO: vlogan nao encontrado"; exit 1; }
	@command -v vcs >/dev/null 2>&1 || { echo "ERRO: vcs nao encontrado"; exit 1; }
	@echo "==> Semana 3: analisando RTL e testbenches com Vlogan..."
	vlogan $(VLOGAN_FLAGS) $(SBOX) $(SUB) $(SHIFT) \
		$(AES_DIR)/minisoc_aes_mix_columns.sv \
		$(AES_DIR)/minisoc_aes_add_round_key.sv \
		$(AES_DIR)/minisoc_aes_inv_sbox.sv \
		$(AES_DIR)/minisoc_aes_inv_sub_bytes.sv \
		$(AES_DIR)/minisoc_aes_inv_shift_rows.sv \
		$(AES_DIR)/minisoc_aes_inv_mix_columns.sv \
		$(TB_DIR)/minisoc_aes_mix_columns_tb.sv \
		$(TB_DIR)/minisoc_aes_add_round_key_tb.sv \
		$(TB_DIR)/minisoc_aes_inv_sub_bytes_tb.sv \
		$(TB_DIR)/minisoc_aes_inv_shift_rows_tb.sv \
		$(TB_DIR)/minisoc_aes_inv_mix_columns_tb.sv
	@echo "==> Semana 3: MixColumns..."
	vcs $(VCS_FLAGS) -top minisoc_aes_mix_columns_tb -o simv_mix_columns_vcs
	./simv_mix_columns_vcs
	@echo "==> Semana 3: AddRoundKey..."
	vcs $(VCS_FLAGS) -top minisoc_aes_add_round_key_tb -o simv_add_round_key_vcs
	./simv_add_round_key_vcs
	@echo "==> Semana 3: InvSubBytes..."
	vcs $(VCS_FLAGS) -top minisoc_aes_inv_sub_bytes_tb -o simv_inv_sub_bytes_vcs
	./simv_inv_sub_bytes_vcs
	@echo "==> Semana 3: InvShiftRows..."
	vcs $(VCS_FLAGS) -top minisoc_aes_inv_shift_rows_tb -o simv_inv_shift_rows_vcs
	./simv_inv_shift_rows_vcs
	@echo "==> Semana 3: InvMixColumns..."
	vcs $(VCS_FLAGS) -top minisoc_aes_inv_mix_columns_tb -o simv_inv_mix_columns_vcs
	./simv_inv_mix_columns_vcs
	@echo "PASS: Semana 3 - Testes Synopsys concluidos!"

# ============================================================================== 
# SEMANA 4 - KEY EXPANSION E DATAPATH (VLOGAN + VCS)
# ============================================================================== 

# Fontes de RTL usadas pelo testbench integrado do Datapath.
SEMANA4_RTL := $(SBOX) $(SUB) $(SHIFT) \
    $(AES_DIR)/minisoc_aes_mix_columns.sv \
    $(AES_DIR)/minisoc_aes_add_round_key.sv \
    $(AES_DIR)/minisoc_aes_inv_sbox.sv \
    $(AES_DIR)/minisoc_aes_inv_sub_bytes.sv \
    $(AES_DIR)/minisoc_aes_inv_shift_rows.sv \
    $(AES_DIR)/minisoc_aes_inv_mix_columns.sv \
    $(AES_DIR)/minisoc_aes_key_exp.sv \
    $(AES_DIR)/minisoc_aes_dp.sv

SEMANA4_TB := $(TB_DIR)/minisoc_aes_key_exp_tb.sv \
    $(TB_DIR)/minisoc_aes_dp_tb.sv

.PHONY: semana4-synopsys
semana4-synopsys:
	@echo "==> Semana 4: verificando ferramentas e arquivos..."
	@command -v vlogan >/dev/null 2>&1 || { echo "ERRO: vlogan nao encontrado"; exit 1; }
	@command -v vcs >/dev/null 2>&1 || { echo "ERRO: vcs nao encontrado"; exit 1; }
	@set -e; for file in $(SEMANA4_RTL) $(SEMANA4_TB); do \
		test -f "$$file" || { echo "ERRO: $$file nao encontrado"; exit 1; }; \
	done
	@echo "==> Semana 4: analisando RTL e testbenches com Vlogan..."
	vlogan $(VLOGAN_FLAGS) $(SEMANA4_RTL) $(SEMANA4_TB)
	@echo "==> Semana 4: Key Expansion..."
	vcs $(VCS_FLAGS) -top minisoc_aes_key_exp_tb -o simv_key_exp_vcs
	./simv_key_exp_vcs
	@echo "==> Semana 4: Datapath AES-128..."
	vcs $(VCS_FLAGS) -top minisoc_aes_dp_tb -o simv_dp_vcs
	./simv_dp_vcs
	@echo "PASS: Semana 4 - Testes Synopsys concluidos!"

# ==============================================================================
# SEMANA 5 - SPI FRONT-END E PLL MOCK (VLOGAN + VCS)
# ==============================================================================

# Modulos RTL implementados na Semana 5.
SEMANA5_RTL := $(RTL_DIR)/minisoc_spi/minisoc_spi.sv \
    $(RTL_DIR)/minisoc_pll/minisoc_pll_mock.sv

# Testbenches individuais e integrado.
SEMANA5_TB := $(TB_DIR)/minisoc_spi_tb.sv \
    $(TB_DIR)/minisoc_pll_mock_tb.sv \
    $(TB_DIR)/minisoc_spi_pll_tb.sv

.PHONY: semana5-synopsys

semana5-synopsys:
	@echo "==> Semana 5: verificando ferramentas e arquivos..."
	@command -v vlogan >/dev/null 2>&1 || { echo "ERRO: vlogan nao encontrado"; exit 1; }
	@command -v vcs >/dev/null 2>&1 || { echo "ERRO: vcs nao encontrado"; exit 1; }
	@set -e; for file in $(SEMANA5_RTL) $(SEMANA5_TB); do \
		test -f "$$file" || { echo "ERRO: $$file nao encontrado"; exit 1; }; \
	done

	@echo "==> Semana 5: compilacao e lint com Vlogan..."
	vlogan $(VLOGAN_FLAGS) $(SEMANA5_RTL) $(SEMANA5_TB)

	@echo "==> Semana 5: teste unitario do SPI Front-End..."
	vcs $(VCS_FLAGS) -top minisoc_spi_tb -o simv_spi_vcs
	./simv_spi_vcs

	@echo "==> Semana 5: teste unitario do PLL mock..."
	vcs $(VCS_FLAGS) -top minisoc_pll_mock_tb -o simv_pll_vcs
	./simv_pll_vcs

	@echo "==> Semana 5: teste integrado SPI + PLL..."
	vcs $(VCS_FLAGS) -top minisoc_spi_pll_tb -o simv_spi_pll_vcs
	./simv_spi_pll_vcs

	@echo "PASS: Semana 5 - Testes Synopsys concluidos!"
