
// ============================================================================
// MiniSoC AES - Memoria compartilhada
// Semana 6 - AES Engine e memoria compartilhada
//
// Block Guide - Secao 7
//
// Memoria single-port sincrona de 1024 palavras de 32 bits.
// Ownership definido por MEM_SEL_AES:
//   0 = interface externa MEMORY DATA.
//   1 = AES Engine.
//
// A memoria nao possui reset nem inicializacao.
// A saida de leitura e registrada e mantem seu valor durante escritas.
// ============================================================================

module minisoc_memory (
    // Controle de ownership.
    input  logic        mem_sel_aes_i,

    // Interface externa MEMORY DATA.
    input  logic        mem_clk_i,
    input  logic [9:0]  ext_addr_i,
    input  logic [31:0] ext_wdata_i,
    input  logic        ext_wr_en_i,
    output logic [31:0] ext_rdata_o,

    // Interface interna AES Engine.
    input  logic        sys_clk_i,
    input  logic [9:0]  aes_addr_i,
    input  logic [31:0] aes_wdata_i,
    input  logic        aes_wr_en_i,
    output logic [31:0] aes_rdata_o
);

    // ========================================================================
    // Estrutura de armazenamento
    // ========================================================================

    logic [31:0] mem [0:1023];

    // ========================================================================
    // Sinais internos do porto unico
    // ========================================================================

    logic        ram_clk;
    logic [9:0]  ram_addr;
    logic [31:0] ram_wdata;
    logic        ram_wr_en;

    logic [31:0] ram_rdata_q;

    // ========================================================================
    // Selecao do proprietario
    // ========================================================================

    // PENDENCIA DE MICROARQUITETURA:
    // A multiplexacao direta dos clocks pode gerar transicoes indevidas
    // durante a troca de ownership.
    //
    // Nesta etapa, a troca deve ocorrer com o AES ocioso, sem operacao
    // externa em andamento, com ambos os clocks em nivel baixo e com
    // os sinais estabilizados antes da proxima borda ativa.
    //
    // O mecanismo definitivo de troca segura de clock sera avaliado
    // durante a integracao completa do MiniSoC.

    assign ram_clk = mem_sel_aes_i ? sys_clk_i : mem_clk_i;

    assign ram_addr = mem_sel_aes_i ? aes_addr_i : ext_addr_i;

    assign ram_wdata = mem_sel_aes_i ? aes_wdata_i : ext_wdata_i;

    assign ram_wr_en = mem_sel_aes_i ? aes_wr_en_i : ext_wr_en_i;

    // ========================================================================
    // Leitura e escrita sincronas
    // ========================================================================

    // Escrita: atualiza a palavra enderecada.
    // Leitura: atualiza a saida registrada.
    // Durante a escrita, a saida de leitura permanece inalterada.
    // Nenhum reset e aplicado ao armazenamento ou a saida.

    always_ff @(posedge ram_clk) begin
        if (ram_wr_en) begin
            mem[ram_addr] <= ram_wdata;
        end else begin
            ram_rdata_q <= mem[ram_addr];
        end
    end

    // ========================================================================
    // Saidas de leitura
    // ========================================================================

    // Apenas o proprietario atual deve utilizar o dado retornado.

    assign ext_rdata_o = ram_rdata_q;
    assign aes_rdata_o = ram_rdata_q;

endmodule
