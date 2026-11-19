
// MiniSoC AES - SPI Front-End.
// SPI Mode 0, MSB-first, frames de 40 bits.
// CDC por toggle com requisicao e confirmacao.
// Banco de registradores no dominio always-on.

module minisoc_spi (
    // Clock e reset.
    input  logic         clk_i,
    input  logic         rst_n_i,

    // Interface SPI.
    input  logic         spi_sclk_i,
    input  logic         spi_cs_n_i,
    input  logic         spi_mosi_i,
    output logic         spi_miso_o,

    // Configuracao do AES.
    output logic [127:0] cfg_key_o,
    output logic [127:0] cfg_iv_o,
    output logic [63:0]  cfg_counter_o,
    output logic [31:0]  cfg_num_blocks_o,
    output logic [2:0]   cfg_mode_o,
    output logic         cfg_decrypt_o,
    output logic         aes_start_o,

    // Status do AES.
    input  logic         aes_busy_i,
    input  logic         aes_done_i,
    input  logic         aes_error_i,
    input  logic [8:0]   aes_blocks_done_i,

    // Controle do sistema e PLL.
    output logic         mem_sel_aes_o,
    output logic         pll_enable_o,
    output logic [1:0]   pll_div_sel_o,

    // Status do PLL.
    input  logic         pll_locked_i
);

    // =====================================================
    // 1. Constantes do protocolo SPI
    // =====================================================

    localparam int FRAME_WIDTH = 40;
    localparam int COUNT_WIDTH = 6;

    // =====================================================
    // 2. Enderecos do banco de registradores
    // =====================================================

    localparam logic [5:0] ADDR_KEY0           = 6'h00;
    localparam logic [5:0] ADDR_KEY1           = 6'h01;
    localparam logic [5:0] ADDR_KEY2           = 6'h02;
    localparam logic [5:0] ADDR_KEY3           = 6'h03;

    localparam logic [5:0] ADDR_IV0            = 6'h04;
    localparam logic [5:0] ADDR_IV1            = 6'h05;
    localparam logic [5:0] ADDR_IV2            = 6'h06;
    localparam logic [5:0] ADDR_IV3            = 6'h07;

    localparam logic [5:0] ADDR_COUNTER_HI     = 6'h08;
    localparam logic [5:0] ADDR_COUNTER_LO     = 6'h09;
    localparam logic [5:0] ADDR_NUM_BLOCKS     = 6'h0A;

    localparam logic [5:0] ADDR_AES_CONTROL    = 6'h0B;
    localparam logic [5:0] ADDR_AES_STATUS     = 6'h0C;
    localparam logic [5:0] ADDR_VERSION        = 6'h0D;
    localparam logic [5:0] ADDR_SYSTEM_CONTROL = 6'h0E;
    localparam logic [5:0] ADDR_SYSTEM_STATUS  = 6'h0F;

    localparam logic [5:0] ADDR_NOP            = 6'h3F;

    // Identificacao da versao do front-end.
    // Valor provisorio, nao especificado pelo Block Guide.
    localparam logic [31:0] VERSION_VALUE = 32'h0001_0000;

    // =====================================================
    // 3. Sinais internos
    // =====================================================

    // Recepcao serial SPI.
    logic [FRAME_WIDTH-1:0] rx_shift_q;
    logic [COUNT_WIDTH-1:0] rx_count_q;

    // Buffer de transferencia CDC.
    logic [FRAME_WIDTH-1:0] rx_frame_q;

    // Requisicao CDC.
    logic req_toggle_q;
    logic req_meta_q;
    logic req_sync_q;

    // Confirmacao CDC.
    logic ack_toggle_q;
    logic ack_meta_q;
    logic ack_sync_q;

    // Captura no dominio always-on.
    logic [FRAME_WIDTH-1:0] frame_sys_q;
    logic frame_valid_q;

    // Sinais de controle.
    logic rst_rx_n;
    logic buffer_free;
    logic frame_pending;

    // Banco de registradores - configuracao AES.
    logic [127:0] cfg_key_q;
    logic [127:0] cfg_iv_q;
    logic [63:0]  cfg_counter_q;
    logic [31:0]  cfg_num_blocks_q;
    logic [2:0]   cfg_mode_q;
    logic         cfg_decrypt_q;
    logic         aes_start_q;

    // Banco de registradores - controle do sistema.
    logic         mem_sel_aes_q;
    logic         pll_enable_q;
    logic [1:0]   pll_div_sel_q;

    // Campos do frame recebido.
    logic         frame_rwb;
    logic [5:0]   frame_addr;
    logic         frame_rsv;
    logic [31:0]  frame_data;

    // Dados de leitura.
    logic [31:0] reg_read_data;
    logic [31:0] read_data_q;
    logic        read_valid_q;

    // Transmissao serial SPI.
    logic [31:0] tx_shift_q;
    logic        tx_nop_header;

    // =====================================================
    // 4. Sinais de controle
    // =====================================================

    // Reset local da interface serial SPI.
    // CS desativado limpa RX e TX.
    // O buffer CDC e os toggles sao preservados.
    assign rst_rx_n = rst_n_i & ~spi_cs_n_i;

    // Buffer livre apos confirmacao sincronizada.
    assign buffer_free =
        (req_toggle_q == ack_sync_q);

    // Nova solicitacao no dominio always-on.
    assign frame_pending =
        (req_sync_q != ack_toggle_q);

    // Identificacao do cabecalho NOP de leitura.
    assign tx_nop_header =
        (rx_shift_q[7:0] == {1'b1, ADDR_NOP, 1'b0});

    // =====================================================
    // 5. Decodificacao dos campos do frame SPI
    // =====================================================

    // Frame de 40 bits:
    // [39]    - RWb: 0 = WRITE, 1 = READ
    // [38:33] - ADDR
    // [32]    - RSV
    // [31:0]  - DATA

    assign frame_rwb  = frame_sys_q[39];
    assign frame_addr = frame_sys_q[38:33];
    assign frame_rsv  = frame_sys_q[32];
    assign frame_data = frame_sys_q[31:0];

    // =====================================================
    // 6. Conexao dos registradores com as saidas
    // =====================================================

    // Saidas de configuracao do AES.
    assign cfg_key_o        = cfg_key_q;
    assign cfg_iv_o         = cfg_iv_q;
    assign cfg_counter_o    = cfg_counter_q;
    assign cfg_num_blocks_o = cfg_num_blocks_q;
    assign cfg_mode_o       = cfg_mode_q;
    assign cfg_decrypt_o    = cfg_decrypt_q;
    assign aes_start_o      = aes_start_q;

    // Saidas de controle do sistema.
    assign mem_sel_aes_o    = mem_sel_aes_q;
    assign pll_enable_o     = pll_enable_q;
    assign pll_div_sel_o    = pll_div_sel_q;

    // =====================================================
    // 7. Recepcao serial SPI
    // =====================================================

    // SPI Mode 0: MOSI amostrado na borda de subida.
    // Recepcao MSB-first com contador saturado em 40 bits.

    always_ff @(posedge spi_sclk_i or negedge rst_rx_n) begin
        if (!rst_rx_n) begin
            rx_shift_q <= '0;
            rx_count_q <= '0;
        end
        else if (rx_count_q < 6'd40) begin
            rx_shift_q <= {
                rx_shift_q[38:0],
                spi_mosi_i
            };

            rx_count_q <= rx_count_q + 6'd1;
        end
    end

    // =====================================================
    // 8. Armazenamento do frame e requisicao CDC
    // =====================================================

    // Publicacao do frame completo na 40a borda de subida.
    // O buffer permanece estavel ate a confirmacao.

    always_ff @(posedge spi_sclk_i or negedge rst_n_i) begin
        if (!rst_n_i) begin
            rx_frame_q   <= '0;
            req_toggle_q <= 1'b0;
        end
        else if (!spi_cs_n_i &&
                 (rx_count_q == 6'd39) &&
                 buffer_free) begin

            rx_frame_q <= {
                rx_shift_q[38:0],
                spi_mosi_i
            };

            req_toggle_q <= ~req_toggle_q;
        end
    end

    // =====================================================
    // 9. Sincronizacao da requisicao: SPI -> clk
    // =====================================================

    // Sincronizador de dois flip-flops.

    always_ff @(posedge clk_i or negedge rst_n_i) begin
        if (!rst_n_i) begin
            req_meta_q <= 1'b0;
            req_sync_q <= 1'b0;
        end
        else begin
            req_meta_q <= req_toggle_q;
            req_sync_q <= req_meta_q;
        end
    end

    // =====================================================
    // 10. Captura do frame e confirmacao CDC
    // =====================================================

    // Captura do frame no dominio always-on.
    // A confirmacao ocorre na borda em que o banco
    // de registradores processa a solicitacao.

    always_ff @(posedge clk_i or negedge rst_n_i) begin
        if (!rst_n_i) begin
            frame_sys_q   <= '0;
            frame_valid_q <= 1'b0;
            ack_toggle_q  <= 1'b0;
        end
        else begin
            if (frame_valid_q) begin

                // O banco de registradores processa
                // o frame nesta mesma borda de clk.

                frame_valid_q <= 1'b0;
                ack_toggle_q  <= req_sync_q;

            end
            else if (frame_pending) begin

                // Captura dos 40 bits do buffer CDC.

                frame_sys_q   <= rx_frame_q;
                frame_valid_q <= 1'b1;

            end
        end
    end

    // =====================================================
    // 11. Sincronizacao da confirmacao: clk -> SPI
    // =====================================================

    // O sincronizador permanece independente do CS,
    // preservando a confirmacao entre transacoes.

    always_ff @(posedge spi_sclk_i or negedge rst_n_i) begin
        if (!rst_n_i) begin
            ack_meta_q <= 1'b0;
            ack_sync_q <= 1'b0;
        end
        else begin
            ack_meta_q <= ack_toggle_q;
            ack_sync_q <= ack_meta_q;
        end
    end

    // =====================================================
    // 12. Decodificacao de leitura do banco de registradores
    // =====================================================

    // Seleciona o valor de 32 bits associado ao endereco.
    // Os bits reservados retornam zero.

    always_comb begin
        reg_read_data = 32'h0000_0000;

        case (frame_addr)

            // Chave AES.
            ADDR_KEY0: reg_read_data = cfg_key_q[127:96];
            ADDR_KEY1: reg_read_data = cfg_key_q[95:64];
            ADDR_KEY2: reg_read_data = cfg_key_q[63:32];
            ADDR_KEY3: reg_read_data = cfg_key_q[31:0];

            // Vetor de inicializacao.
            ADDR_IV0: reg_read_data = cfg_iv_q[127:96];
            ADDR_IV1: reg_read_data = cfg_iv_q[95:64];
            ADDR_IV2: reg_read_data = cfg_iv_q[63:32];
            ADDR_IV3: reg_read_data = cfg_iv_q[31:0];

            // Contador CTR.
            ADDR_COUNTER_HI:
                reg_read_data = cfg_counter_q[63:32];

            ADDR_COUNTER_LO:
                reg_read_data = cfg_counter_q[31:0];

            // Quantidade de blocos.
            ADDR_NUM_BLOCKS:
                reg_read_data = cfg_num_blocks_q;

            // Controle AES.
            // [4:2] MODE
            // [1]   DECRYPT
            // [0]   START: retorna zero na leitura.
            ADDR_AES_CONTROL:
                reg_read_data = {
                    27'b0,
                    cfg_mode_q,
                    cfg_decrypt_q,
                    1'b0
                };

            // Status AES.
            // [11:3] BLOCKS_DONE
            // [2]    ERROR
            // [1]    DONE
            // [0]    BUSY
            ADDR_AES_STATUS:
                reg_read_data = {
                    20'b0,
                    aes_blocks_done_i,
                    aes_error_i,
                    aes_done_i,
                    aes_busy_i
                };

            // Identificacao da versao.
            ADDR_VERSION:
                reg_read_data = VERSION_VALUE;

            // Controle do sistema.
            // [3:2] PLL_DIV_SEL
            // [1]   PLL_ENABLE
            // [0]   MEM_SEL_AES
            ADDR_SYSTEM_CONTROL:
                reg_read_data = {
                    28'b0,
                    pll_div_sel_q,
                    pll_enable_q,
                    mem_sel_aes_q
                };

            // Status do PLL.
            // [0] PLL_LOCKED
            ADDR_SYSTEM_STATUS:
                reg_read_data = {
                    31'b0,
                    pll_locked_i
                };

            // Enderecos nao implementados.
            default:
                reg_read_data = 32'h0000_0000;

        endcase
    end

    // =====================================================
    // 13. Banco de registradores - escrita e resposta de leitura
    // =====================================================

    // Todo o banco opera no dominio clk always-on,
    // independentemente da habilitacao do PLL.

    always_ff @(posedge clk_i or negedge rst_n_i) begin
        if (!rst_n_i) begin

            // Configuracao AES.
            cfg_key_q        <= '0;
            cfg_iv_q         <= '0;
            cfg_counter_q    <= '0;
            cfg_num_blocks_q <= '0;
            cfg_mode_q       <= 3'b000;
            cfg_decrypt_q    <= 1'b0;
            aes_start_q      <= 1'b0;

            // Controle do sistema.
            mem_sel_aes_q    <= 1'b0;
            pll_enable_q     <= 1'b0;
            pll_div_sel_q    <= 2'b00;

            // Resposta de leitura.
            read_data_q      <= '0;
            read_valid_q     <= 1'b0;

        end
        else begin

            // START funciona como write-one-pulse.
            aes_start_q <= 1'b0;

            // Processar frames completos com RSV igual a zero.
            if (frame_valid_q && !frame_rsv) begin

                // -----------------------------------------
                // NOP - retorno da resposta de leitura
                // -----------------------------------------

                if (frame_addr == ADDR_NOP) begin

                    // Invalida a resposta apos um NOP
                    // de leitura completo.
                    if (frame_rwb)
                        read_valid_q <= 1'b0;

                end

                // -----------------------------------------
                // Operacao WRITE
                // -----------------------------------------

                else if (!frame_rwb) begin

                    case (frame_addr)

                        // Chave AES.
                        ADDR_KEY0:
                            cfg_key_q[127:96] <= frame_data;

                        ADDR_KEY1:
                            cfg_key_q[95:64] <= frame_data;

                        ADDR_KEY2:
                            cfg_key_q[63:32] <= frame_data;

                        ADDR_KEY3:
                            cfg_key_q[31:0] <= frame_data;

                        // Vetor de inicializacao.
                        ADDR_IV0:
                            cfg_iv_q[127:96] <= frame_data;

                        ADDR_IV1:
                            cfg_iv_q[95:64] <= frame_data;

                        ADDR_IV2:
                            cfg_iv_q[63:32] <= frame_data;

                        ADDR_IV3:
                            cfg_iv_q[31:0] <= frame_data;

                        // Contador CTR.
                        ADDR_COUNTER_HI:
                            cfg_counter_q[63:32] <= frame_data;

                        ADDR_COUNTER_LO:
                            cfg_counter_q[31:0] <= frame_data;

                        // Quantidade de blocos.
                        ADDR_NUM_BLOCKS:
                            cfg_num_blocks_q <= frame_data;

                        // Controle AES.
                        ADDR_AES_CONTROL: begin
                            cfg_mode_q    <= frame_data[4:2];
                            cfg_decrypt_q <= frame_data[1];
                            aes_start_q   <= frame_data[0];
                        end

                        // Controle do sistema.
                        ADDR_SYSTEM_CONTROL: begin
                            pll_div_sel_q <= frame_data[3:2];
                            pll_enable_q  <= frame_data[1];
                            mem_sel_aes_q <= frame_data[0];
                        end

                        // Registradores somente leitura
                        // e enderecos nao implementados.
                        default: begin
                            // Escrita ignorada.
                        end

                    endcase
                end

                // -----------------------------------------
                // Operacao READ request
                // -----------------------------------------

                else begin

                    // Armazena uma copia do valor lido.
                    // A resposta permanece disponivel para
                    // a segunda transacao SPI.

                    read_data_q  <= reg_read_data;
                    read_valid_q <= 1'b1;

                end
            end
        end
    end


    // =====================================================
    // 14. Transmissao serial SPI
    // =====================================================

    // SPI Mode 0: MISO atualizado na borda de descida.
    // Transmissao MSB-first utilizando o contador do RX.

    always_ff @(negedge spi_sclk_i or negedge rst_rx_n) begin

        if (!rst_rx_n) begin

            tx_shift_q <= '0;

        end
        else begin

            // Durante a recepcao do cabecalho.
            if (rx_count_q < 6'd8) begin

                tx_shift_q <= '0;

            end

            // Cabecalho completo: carregar a resposta.
            else if (rx_count_q == 6'd8) begin

                if (tx_nop_header &&
                    buffer_free   &&
                    read_valid_q) begin

                    tx_shift_q <= read_data_q;

                end
                else begin

                    tx_shift_q <= '0;

                end
            end

            // Transmissao dos bits restantes.
            else if (rx_count_q < 6'd40) begin

                tx_shift_q <= {
                    tx_shift_q[30:0],
                    1'b0
                };

            end

            // Transacao concluida.
            else begin

                tx_shift_q <= '0;

            end
        end
    end

    // Saida serial MSB-first.
    assign spi_miso_o = tx_shift_q[31];

endmodule
