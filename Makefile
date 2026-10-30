
# ==============================================================================
# Makefile - MiniSoC AES | Trilha RTL Design
#
# Semana 1: Porta AND - Synopsys
# Semana 2: S-box, SubBytes e ShiftRows
#
# Comandos:
#   make semana1             Semana 1 com Synopsys
#   make semana2             Semana 2 com Icarus + Verilator
#   make semana2-synopsys    Semana 2 com Vlogan + VCS
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

VLOGAN_FLAGS := -full64 -sverilog -kdb +lint=all

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

semana2-synopsys:
	@$(MAKE) WEEK=2 run

# ==============================================================================
# FLUXO CODESPACES - ICARUS VERILOG E VERILATOR
# ==============================================================================

check-codespaces:
	@echo "==> Verificando ferramentas do Codespaces..."
	@command -v iverilog >/dev/null 2>&1 || { echo "ERRO: iverilog nao encontrado"; exit 1; }
	@command -v vvp >/dev/null 2>&1 || { echo "ERRO: vvp nao encontrado"; exit 1; }
	@command -v verilator >/dev/null 2>&1 || { echo "ERRO: verilator nao encontrado"; exit 1; }
	@set -e; for file in $(SBOX) $(SUB) $(SHIFT) $(TB_SBOX) $(TB_SUB) $(TB_SHIFT) $(SBOX_REF); do \
		test -f "$$file" || { echo "ERRO: $$file nao encontrado"; exit 1; }; \
	done
	@echo "==> Ambiente OK."

semana2: semana2-codespaces

semana2-codespaces: check-codespaces
	@echo "==> Testando S-box..."
	iverilog -g2012 -s minisoc_aes_sbox_tb -o simv_sbox $(SBOX) $(TB_SBOX)
	vvp simv_sbox

	@echo "==> Testando SubBytes..."
	iverilog -g2012 -s minisoc_aes_sub_bytes_tb -o simv_sub_bytes $(SBOX) $(SUB) $(TB_SUB)
	vvp simv_sub_bytes

	@echo "==> Testando ShiftRows..."
	iverilog -g2012 -s minisoc_aes_shift_rows_tb -o simv_shift_rows $(SHIFT) $(TB_SHIFT)
	vvp simv_shift_rows

	@echo "==> Lint da S-box..."
	verilator --lint-only -Wall --top-module minisoc_aes_sbox $(SBOX)

	@echo "==> Lint do SubBytes..."
	verilator --lint-only -Wall --top-module minisoc_aes_sub_bytes $(SBOX) $(SUB)

	@echo "==> Lint do ShiftRows..."
	verilator --lint-only -Wall --top-module minisoc_aes_shift_rows $(SHIFT)

	@echo "========================================"
	@echo "PASS: SEMANA 2 - TESTES E LINT APROVADOS!"
	@echo "========================================"

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
	@echo "  make semana2            Semana 2 - Codespaces"
	@echo "  make semana2-synopsys   Semana 2 - Synopsys"
	@echo "  make WEEK=2 syntax      Analise com Vlogan"
	@echo "  make clean              Limpa arquivos temporarios"

.PHONY: all check syntax compile run semana1 \
        semana2 semana2-codespaces semana2-synopsys \
        check-codespaces clean help
