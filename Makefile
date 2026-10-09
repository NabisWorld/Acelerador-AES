# ==============================================================================
# Makefile - Acelerador AES
# Trilha RTL - Semana 1
#
# Fluxo mínimo:
#   análise/lint -> compilação -> simulação
#
# Ferramentas:
#   vlogan  : análise SystemVerilog + lint
#   vcs     : compilação/elaboração
#   simv    : simulação
# ==============================================================================


# ------------------------------------------------------------------------------
# Diretórios
# ------------------------------------------------------------------------------

RTL_DIR := rtl
TB_DIR  := tb


# ------------------------------------------------------------------------------
# Arquivos
# ------------------------------------------------------------------------------

RTL_FILES := $(RTL_DIR)/porta_and.sv
TB_FILES  := $(TB_DIR)/porta_and_tb.sv


# ------------------------------------------------------------------------------
# Top-level da simulação
# ------------------------------------------------------------------------------

TOP := porta_and_tb


# ------------------------------------------------------------------------------
# Configurações
# ------------------------------------------------------------------------------

TIMESCALE := 1ns/1ps

VLOGAN_FLAGS := -full64 \
                -sverilog \
                -kdb \
                +lint=all

VCS_FLAGS := -full64 \
             -timescale=$(TIMESCALE) \
             -debug_access+all \
             -kdb


# ==============================================================================
# Fluxo principal
#
# Executado com:
#
#   make
#
# ou:
#
#   make all
# ==============================================================================

all: run


# ------------------------------------------------------------------------------
# Verificação do ambiente
# ------------------------------------------------------------------------------

check:
	@echo "==> Verificando ambiente..."

	@command -v vlogan >/dev/null 2>&1 || \
		(echo "ERRO: vlogan não encontrado."; exit 1)

	@command -v vcs >/dev/null 2>&1 || \
		(echo "ERRO: vcs não encontrado."; exit 1)

	@test -f $(RTL_FILES) || \
		(echo "ERRO: $(RTL_FILES) não encontrado."; exit 1)

	@test -f $(TB_FILES) || \
		(echo "ERRO: $(TB_FILES) não encontrado."; exit 1)

	@echo "==> Ambiente OK."


# ------------------------------------------------------------------------------
# Análise SystemVerilog + lint
# ------------------------------------------------------------------------------

syntax: check
	@echo ""
	@echo "==> Analisando SystemVerilog e executando lint..."

	vlogan $(VLOGAN_FLAGS) \
		$(RTL_FILES) \
		$(TB_FILES)


# ------------------------------------------------------------------------------
# Compilação / elaboração
# ------------------------------------------------------------------------------

compile: syntax
	@echo ""
	@echo "==> Compilando e elaborando com VCS..."

	vcs $(VCS_FLAGS) \
		-top $(TOP)


# ------------------------------------------------------------------------------
# Simulação
# ------------------------------------------------------------------------------

run: compile
	@echo ""
	@echo "==> Executando simulação..."

	./simv


# ------------------------------------------------------------------------------
# Limpeza
# ------------------------------------------------------------------------------

clean:
	@echo "==> Removendo arquivos gerados..."

	rm -rf \
		csrc \
		simv \
		simv.daidir \
		*.daidir \
		AN.DB \
		ucli.key \
		novas* \
		verdiLog \
		DVEfiles \
		.vlogan* \
		vc_hdrs.h \
		*.log

	@echo "==> Limpeza concluída."


# ------------------------------------------------------------------------------
# Ajuda
# ------------------------------------------------------------------------------

help:
	@echo ""
	@echo "Acelerador AES - Semana 1"
	@echo ""
	@echo "Comandos disponíveis:"
	@echo "  make            Executa o fluxo completo"
	@echo "  make check      Verifica ambiente e arquivos"
	@echo "  make syntax     Executa análise e lint"
	@echo "  make compile    Compila/elabora com VCS"
	@echo "  make run        Executa a simulação"
	@echo "  make clean      Remove arquivos gerados"
	@echo "  make help       Exibe esta ajuda"
	@echo ""


.PHONY: all check syntax compile run clean help