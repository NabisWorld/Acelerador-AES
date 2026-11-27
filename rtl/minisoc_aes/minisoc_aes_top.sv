
/*
 * MiniSoC AES-128 - Controlador principal do AES Engine.
 *
 * Semana 6:
 * Processamento multi-bloco nos modos ECB, CBC e CTR.
 * Reutiliza os modulos de expansao de chave e datapath.
 * Processamento in-place na memoria compartilhada.
 */

module minisoc_aes_top (

    // Clock e reset.
    input  logic         clk_i,
    input  logic         rst_n_i,

    // Interface de configuracao.
    input  logic         start_i,
    input  logic [127:0] cfg_key_i,
    input  logic [127:0] cfg_iv_i,
    input  logic [63:0]  cfg_counter_i,
    input  logic [31:0]  cfg_num_blocks_i,
    input  logic [2:0]   cfg_mode_i,
    input  logic         cfg_decrypt_i,

    // Interface de status.
    output logic         busy_o,
    output logic         done_o,
    output logic         error_o,
    output logic [8:0]   blocks_done_o,

    // Interface com a memoria.
    output logic [9:0]   mem_addr_o,
    output logic [31:0]  mem_wdata_o,
    output logic         mem_wr_en_o,
    input  logic [31:0]  mem_rdata_i

);

    // ============================================================
    // 1. Constantes dos modos de operacao
    // ============================================================

    localparam logic [2:0] MODE_ECB  = 3'b000;
    localparam logic [2:0] MODE_CBC  = 3'b001;
    localparam logic [2:0] MODE_PCBC = 3'b010;
    localparam logic [2:0] MODE_CFB  = 3'b011;
    localparam logic [2:0] MODE_OFB  = 3'b100;
    localparam logic [2:0] MODE_CTR  = 3'b101;

    // Limites da quantidade de blocos.
    localparam logic [31:0] MIN_BLOCKS = 32'd1;
    localparam logic [31:0] MAX_BLOCKS = 32'd256;


    // ============================================================
    // 2. FSM principal
    // ============================================================

    typedef enum logic [3:0] {
        ST_IDLE,
        ST_SETUP,
        ST_READ_BLOCK,
        ST_PREP_AES,
        ST_AES_RUN,
        ST_POST_AES,
        ST_WRITE_BLOCK,
        ST_CHECK_BLOCK,
        ST_FINISH
    } aes_top_state_t;

    aes_top_state_t state_fsm_q;


    // ============================================================
    // 3. Registradores de configuracao
    // ============================================================

    logic [127:0] key_q;
    logic [127:0] iv_q;
    logic [63:0]  counter_q;
    logic [2:0]   mode_q;
    logic         decrypt_q;
    logic [8:0]   num_blocks_q;


    // ============================================================
    // 4. Registradores de dados
    // ============================================================

    logic [127:0] block_in_q;
    logic [127:0] dp_block_q;
    logic [127:0] block_out_q;

    logic dp_decrypt_q;


    // ============================================================
    // 5. Controle da memoria
    // ============================================================

    logic [1:0] word_idx_q;
    logic       read_phase_q;


    // ============================================================
    // 6. Registradores de status
    // ============================================================

    logic       done_q;
    logic       error_q;
    logic [8:0] blocks_done_q;


    // ============================================================
    // 7. Sinais internos dos modulos criptograficos
    // ============================================================

    // Controle da expansao de chave.
    logic key_start_q;
    logic key_busy;
    logic key_done;
    logic keys_valid;

    // Controle do datapath.
    logic dp_start_q;
    logic dp_busy;
    logic dp_done;

    logic [127:0] dp_result;

    // Interface de round keys.
    logic [3:0]   round_sel;
    logic [127:0] round_key;


    // ============================================================
    // 8. Instanciacao da expansao de chave
    // ============================================================

    minisoc_aes_key_exp u_key_exp (
        .clk_i        (clk_i),
        .rst_n_i      (rst_n_i),
        .start_i      (key_start_q),
        .key_i        (key_q),
        .round_sel_i  (round_sel),

        .round_key_o  (round_key),
        .busy_o       (key_busy),
        .done_o       (key_done),
        .keys_valid_o (keys_valid)
    );


    // ============================================================
    // 9. Instanciacao do datapath AES
    // ============================================================

    minisoc_aes_dp u_aes_dp (
        .clk_i        (clk_i),
        .rst_n_i      (rst_n_i),
        .start_i      (dp_start_q),
        .decrypt_i    (dp_decrypt_q),
        .block_i      (dp_block_q),
        .keys_valid_i (keys_valid),
        .round_key_i  (round_key),

        .round_sel_o  (round_sel),
        .block_o      (dp_result),
        .busy_o       (dp_busy),
        .done_o       (dp_done)
    );


    // ============================================================
    // 10. Validacao das configuracoes
    // ============================================================

    logic num_blocks_valid;
    logic mode_valid;
    logic mode_supported;
    logic config_valid;

    assign num_blocks_valid =
        (cfg_num_blocks_i >= MIN_BLOCKS) &&
        (cfg_num_blocks_i <= MAX_BLOCKS);

    assign mode_valid =
        (cfg_mode_i <= MODE_CTR);

    assign mode_supported =
        (cfg_mode_i == MODE_ECB) ||
        (cfg_mode_i == MODE_CBC) ||
        (cfg_mode_i == MODE_CTR);

    assign config_valid =
        num_blocks_valid &&
        mode_valid &&
        mode_supported;


    // ============================================================
    // 11. Saidas de status
    // ============================================================

    assign busy_o        = (state_fsm_q != ST_IDLE);
    assign done_o        = done_q;
    assign error_o       = error_q;
    assign blocks_done_o = blocks_done_q;


    // ============================================================
    // 12. Controle da interface com a memoria
    // ============================================================

    always_comb begin

        // Valores padrao.
        mem_addr_o  = 10'd0;
        mem_wdata_o = 32'd0;
        mem_wr_en_o = 1'b0;

        if (rst_n_i) begin

            case (state_fsm_q)

                ST_READ_BLOCK: begin

                    mem_addr_o =
                        {blocks_done_q[7:0], word_idx_q};

                end

                ST_WRITE_BLOCK: begin

                    mem_addr_o =
                        {blocks_done_q[7:0], word_idx_q};

                    mem_wr_en_o = 1'b1;

                    case (word_idx_q)
                        2'd0: mem_wdata_o = block_out_q[127:96];
                        2'd1: mem_wdata_o = block_out_q[95:64];
                        2'd2: mem_wdata_o = block_out_q[63:32];
                        2'd3: mem_wdata_o = block_out_q[31:0];

                        default: mem_wdata_o = 32'd0;
                    endcase

                end

                default: begin

                    mem_addr_o  = 10'd0;
                    mem_wdata_o = 32'd0;
                    mem_wr_en_o = 1'b0;

                end

            endcase

        end

    end




// ============================================================
// 13. Controle sequencial da FSM principal
// ============================================================

always_ff @(posedge clk_i or negedge rst_n_i) begin

    if (!rst_n_i) begin

        // Estado inicial da FSM.
        state_fsm_q <= ST_IDLE;

        // Registradores de configuracao.
        key_q        <= 128'd0;
        iv_q         <= 128'd0;
        counter_q    <= 64'd0;
        mode_q       <= MODE_ECB;
        decrypt_q    <= 1'b0;
        num_blocks_q <= 9'd0;

        // Registradores de dados.
        block_in_q   <= 128'd0;
        dp_block_q   <= 128'd0;
        block_out_q  <= 128'd0;
        dp_decrypt_q <= 1'b0;

        // Controle da memoria.
        word_idx_q   <= 2'd0;
        read_phase_q <= 1'b0;

        // Registradores de status.
        done_q        <= 1'b0;
        error_q       <= 1'b0;
        blocks_done_q <= 9'd0;

        // Pulsos de acionamento.
        key_start_q <= 1'b0;
        dp_start_q  <= 1'b0;

    end else begin

        // Pulsos desativados por padrao.
        key_start_q <= 1'b0;
        dp_start_q  <= 1'b0;

        // Implementacao dos estados da FSM.

case (state_fsm_q)


// ------------------------------------------------------------
// ST_IDLE - Aceitacao de uma nova operacao
// ------------------------------------------------------------

ST_IDLE: begin

    if (start_i) begin

        if (config_valid) begin

            // Captura das configuracoes.
            key_q        <= cfg_key_i;
            iv_q         <= cfg_iv_i;
            counter_q    <= cfg_counter_i;
            mode_q       <= cfg_mode_i;
            decrypt_q    <= cfg_decrypt_i;
            num_blocks_q <= cfg_num_blocks_i[8:0];

            // Reinicializacao do status.
            done_q        <= 1'b0;
            error_q       <= 1'b0;
            blocks_done_q <= 9'd0;

            // Inicializacao do controle da memoria.
            word_idx_q   <= 2'd0;
            read_phase_q <= 1'b0;

            // Acionamento da expansao de chave.
            key_start_q <= 1'b1;

            // Avanco da FSM.
            state_fsm_q <= ST_SETUP;

        end else begin

            // Configuracao invalida ou modo nao suportado.
            error_q <= 1'b1;

        end

    end

end


// ------------------------------------------------------------
// ST_SETUP - Expansao de chave
// ------------------------------------------------------------

ST_SETUP: begin

    if (key_done && keys_valid) begin

        // Expansao concluida.
        // Todas as round keys estao disponiveis.

        state_fsm_q <= ST_READ_BLOCK;

    end

end


// ------------------------------------------------------------
// ST_READ_BLOCK - Leitura do bloco de 128 bits
// ------------------------------------------------------------

ST_READ_BLOCK: begin

    if (!read_phase_q) begin

        // Fase 0:
        // A memoria registra o dado do endereco atual.
        read_phase_q <= 1'b1;

    end else begin

        // Fase 1:
        // Captura do dado retornado pela memoria.
        case (word_idx_q)

            2'd0: block_in_q[127:96] <= mem_rdata_i;
            2'd1: block_in_q[95:64]  <= mem_rdata_i;
            2'd2: block_in_q[63:32]  <= mem_rdata_i;
            2'd3: block_in_q[31:0]   <= mem_rdata_i;

            default: block_in_q <= block_in_q;

        endcase

        // Retorno para a fase de leitura.
        read_phase_q <= 1'b0;

        // Verificacao da ultima palavra do bloco.
        if (word_idx_q == 2'd3) begin

            word_idx_q  <= 2'd0;
            state_fsm_q <= ST_PREP_AES;

        end else begin

            // Avanco para a proxima palavra.
            word_idx_q <= word_idx_q + 2'd1;

        end

    end

end


// ------------------------------------------------------------
// ST_PREP_AES - Preparacao da entrada do datapath
// ------------------------------------------------------------

ST_PREP_AES: begin

    case (mode_q)

        MODE_ECB: begin

            // ECB Encrypt / Decrypt.
            dp_block_q   <= block_in_q;
            dp_decrypt_q <= decrypt_q;

        end

        MODE_CBC: begin

            if (decrypt_q) begin

                // CBC Decrypt.
                dp_block_q <= block_in_q;

            end else begin

                // CBC Encrypt.
                dp_block_q <= block_in_q ^ iv_q;

            end

            dp_decrypt_q <= decrypt_q;

        end

        MODE_CTR: begin

            // CTR Encrypt / Decrypt.
            // A primitiva AES Encrypt e sempre utilizada.
            dp_block_q   <= iv_q ^ {64'b0, counter_q};
            dp_decrypt_q <= 1'b0;

        end

        default: begin

            // Valores seguros para modo inesperado.
            dp_block_q   <= 128'd0;
            dp_decrypt_q <= 1'b0;

        end

    endcase

    // Acionamento do datapath apenas para modos suportados.
    if ((mode_q == MODE_ECB) ||
        (mode_q == MODE_CBC) ||
        (mode_q == MODE_CTR)) begin

        dp_start_q  <= 1'b1;
        state_fsm_q <= ST_AES_RUN;

    end else begin

        // Protecao contra modo interno inesperado.
        error_q     <= 1'b1;
        state_fsm_q <= ST_IDLE;

    end

end


// ------------------------------------------------------------
// ST_AES_RUN - Execucao da primitiva AES
// ------------------------------------------------------------

ST_AES_RUN: begin

    if (dp_done) begin

        // Captura do resultado criptografico.
        block_out_q <= dp_result;

        // Avanco para o pos-processamento.
        state_fsm_q <= ST_POST_AES;

    end

end


// ------------------------------------------------------------
// ST_POST_AES - Pos-processamento do resultado
// ------------------------------------------------------------

ST_POST_AES: begin

    case (mode_q)

        MODE_ECB: begin

            // ECB Encrypt / Decrypt.
            // O resultado do datapath ja e o resultado final.
            state_fsm_q <= ST_WRITE_BLOCK;

        end

        MODE_CBC: begin

            if (decrypt_q) begin

                // CBC Decrypt.
                block_out_q <= block_out_q ^ iv_q;

                // Ciphertext original para o proximo bloco.
                iv_q <= block_in_q;

            end else begin

                // CBC Encrypt.
                // Atualizacao do vetor de encadeamento.
                iv_q <= block_out_q;

            end

            state_fsm_q <= ST_WRITE_BLOCK;

        end

        MODE_CTR: begin

            // CTR Encrypt / Decrypt.
            // XOR entre o bloco original e o keystream.
            block_out_q <= block_in_q ^ block_out_q;

            // Incremento do contador.
            counter_q <= counter_q + 64'd1;

            state_fsm_q <= ST_WRITE_BLOCK;

        end

        default: begin

            // Protecao contra modo interno inesperado.
            error_q     <= 1'b1;
            state_fsm_q <= ST_IDLE;

        end

    endcase

end

// ------------------------------------------------------------
// ST_WRITE_BLOCK - Escrita do resultado na memoria
// ------------------------------------------------------------

ST_WRITE_BLOCK: begin

    // A escrita e realizada pela memoria na borda de clock.
    // Endereco, dado e write enable sao gerados
    // pela logica combinacional.

    if (word_idx_q == 2'd3) begin

        // Ultima palavra do bloco escrita.
        word_idx_q <= 2'd0;

        // Avanco para a verificacao dos blocos.
        state_fsm_q <= ST_CHECK_BLOCK;

    end else begin

        // Avanco para a proxima palavra.
        word_idx_q <= word_idx_q + 2'd1;

    end

end

// ------------------------------------------------------------
// ST_CHECK_BLOCK - Contagem e verificacao dos blocos
// ------------------------------------------------------------

ST_CHECK_BLOCK: begin

    // Contabiliza o bloco completamente processado e escrito.
    blocks_done_q <= blocks_done_q + 9'd1;

    // Verifica a quantidade de blocos incluindo o bloco atual.
    if ((blocks_done_q + 9'd1) == num_blocks_q) begin

        // Todos os blocos foram processados.
        state_fsm_q <= ST_FINISH;

    end else begin

        // Preparacao para a leitura do proximo bloco.
        word_idx_q   <= 2'd0;
        read_phase_q <= 1'b0;

        // Retorno para a leitura da memoria.
        state_fsm_q <= ST_READ_BLOCK;

    end

end

// ------------------------------------------------------------
// ST_FINISH - Finalizacao da operacao
// ------------------------------------------------------------

ST_FINISH: begin

    // Sinaliza a conclusao da operacao.
    done_q <= 1'b1;

    // Retorno ao estado inicial.
    state_fsm_q <= ST_IDLE;

end

// ------------------------------------------------------------
// Tratamento de estados ilegais
// ------------------------------------------------------------

default: begin

    // Sinaliza erro e retorna ao estado inicial.
    error_q     <= 1'b1;
    state_fsm_q <= ST_IDLE;

end

        endcase

    end

end

endmodule