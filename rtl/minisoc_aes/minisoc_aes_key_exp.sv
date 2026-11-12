// MiniSoC AES-128 - Expansao de chave pre-computada e sequencial.
// A cada ciclo de geracao, calcula UMA chave completa de rodada (128 bits).
// K0 = chave original; K1..K10 geradas em 10 ciclos apos aceitar start_i.
// Reutiliza a S-box combinacional ja implementada na Semana 2.
module minisoc_aes_key_exp (
    input  logic         clk_i,
    input  logic         rst_n_i,
    input  logic         start_i,
    input  logic [127:0] key_i,
    input  logic [3:0]   round_sel_i,
    output logic [127:0] round_key_o,
    output logic         busy_o,
    output logic         done_o,
    output logic         keys_valid_o
);

    localparam logic [3:0] LAST_ROUND = 4'd10;

    logic [127:0] round_keys_q [0:10];
    logic [127:0] current_key_q;
    logic [3:0]   round_idx_q;

    logic [31:0] rot_word;
    logic [31:0] sub_word;
    logic [31:0] g_word;
    logic [31:0] next_w0, next_w1, next_w2, next_w3;
    logic [127:0] next_key;

    // Rcon da expansao AES-128 (rodadas 1 a 10).
    function automatic logic [7:0] rcon(input logic [3:0] round_idx);
        case (round_idx)
            4'd1:  rcon = 8'h01;
            4'd2:  rcon = 8'h02;
            4'd3:  rcon = 8'h04;
            4'd4:  rcon = 8'h08;
            4'd5:  rcon = 8'h10;
            4'd6:  rcon = 8'h20;
            4'd7:  rcon = 8'h40;
            4'd8:  rcon = 8'h80;
            4'd9:  rcon = 8'h1B;
            4'd10: rcon = 8'h36;
            default: rcon = 8'h00;
        endcase
    endfunction

    // RotWord(W3): {b0,b1,b2,b3} -> {b1,b2,b3,b0}.
    assign rot_word = {current_key_q[23:0], current_key_q[31:24]};

    // SubWord: quatro S-boxes existentes, uma por byte do RotWord.
    // Gera uma chave de 128 bits por ciclo (em vez de uma palavra por ciclo).
    generate
        for (genvar i = 0; i < 4; i++) begin : gen_sub_word
            minisoc_aes_sbox u_sbox (
                .byte_in (rot_word[31-(8*i) -: 8]),
                .byte_out(sub_word[31-(8*i) -: 8])
            );
        end
    endgenerate

    assign g_word  = sub_word ^ {rcon(round_idx_q), 24'h000000};

    // Chave atual = {W0,W1,W2,W3}.
    // Nova chave = {W0',W1',W2',W3'}.
    assign next_w0 = current_key_q[127:96] ^ g_word;
    assign next_w1 = current_key_q[95:64]  ^ next_w0;
    assign next_w2 = current_key_q[63:32]  ^ next_w1;
    assign next_w3 = current_key_q[31:0]   ^ next_w2;
    assign next_key = {next_w0, next_w1, next_w2, next_w3};

    // Banco de round keys: 11 x 128 bits.
    always_ff @(posedge clk_i or negedge rst_n_i) begin
        if (!rst_n_i) begin
            current_key_q <= '0;
            round_idx_q  <= 4'd0;
            busy_o       <= 1'b0;
            done_o       <= 1'b0;
            keys_valid_o <= 1'b0;
            for (int i = 0; i < 11; i++) begin
                round_keys_q[i] <= '0;
            end
        end else begin
            done_o <= 1'b0; // Pulso de conclusao, nunca sticky.

            if (!busy_o) begin
                if (start_i) begin
                    round_keys_q[0] <= key_i; // K0.
                    current_key_q   <= key_i;
                    round_idx_q    <= 4'd1;
                    busy_o         <= 1'b1;
                    keys_valid_o   <= 1'b0;
                end
            end else begin
                // Em cada borda, registra uma nova chave de rodada.
                round_keys_q[round_idx_q] <= next_key;
                current_key_q            <= next_key;

                if (round_idx_q == LAST_ROUND) begin
                    busy_o       <= 1'b0;
                    done_o       <= 1'b1;
                    keys_valid_o <= 1'b1;
                end else begin
                    round_idx_q <= round_idx_q + 4'd1;
                end
            end
        end
    end

    // Leitura combinacional das chaves ja prontas.
    always_comb begin
        round_key_o = '0;
        if (keys_valid_o && (round_sel_i <= LAST_ROUND)) begin
            round_key_o = round_keys_q[round_sel_i];
        end
    end

endmodule
