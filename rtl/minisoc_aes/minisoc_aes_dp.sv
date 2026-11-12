// MiniSoC AES-128 - Datapath iterativo de um bloco de 128 bits.
// A FSM principal minisoc_aes_top deve pre-computar K0..K10 antes de start_i.
// Uma rodada intermediaria e executada por ciclo; as etapas INIT/FINAL sao separadas.
module minisoc_aes_dp (
    input  logic         clk_i,
    input  logic         rst_n_i,
    input  logic         start_i,
    input  logic         decrypt_i,
    input  logic [127:0] block_i,
    input  logic         keys_valid_i,
    input  logic [127:0] round_key_i,

    output logic [3:0]   round_sel_o,
    output logic [127:0] block_o,
    output logic         busy_o,
    output logic         done_o
);

    typedef enum logic [2:0] {
        ST_IDLE,
        ST_INIT,
        ST_ROUND,
        ST_FINAL_ROUND,
        ST_DONE
    } aes_state_t;

    aes_state_t   state_fsm_q;
    logic [127:0] state_q;
    logic [3:0]   round_idx_q;
    logic         decrypt_q;

    // Transformacoes diretas, encadeadas combinacionalmente.
    logic [127:0] sub_bytes_out;
    logic [127:0] shift_rows_out;
    logic [127:0] mix_columns_out;

    minisoc_aes_sub_bytes u_sub_bytes (
        .state_in (state_q),
        .state_out(sub_bytes_out)
    );

    minisoc_aes_shift_rows u_shift_rows (
        .state_in (sub_bytes_out),
        .state_out(shift_rows_out)
    );

    minisoc_aes_mix_columns u_mix_columns (
        .state_in (shift_rows_out),
        .state_out(mix_columns_out)
    );

    // Transformacoes inversas, tambem encadeadas combinacionalmente.
    logic [127:0] inv_shift_rows_out;
    logic [127:0] inv_sub_bytes_out;
    logic [127:0] inv_mix_columns_out;

    minisoc_aes_inv_shift_rows u_inv_shift_rows (
        .state_in (state_q),
        .state_out(inv_shift_rows_out)
    );

    minisoc_aes_inv_sub_bytes u_inv_sub_bytes (
        .state_in (inv_shift_rows_out),
        .state_out(inv_sub_bytes_out)
    );

    // AddRoundKey compartilhado entre os dois sentidos.
    logic [127:0] ark_in;
    logic [127:0] ark_out;

    minisoc_aes_add_round_key u_add_round_key (
        .state_in (ark_in),
        .round_key(round_key_i),
        .state_out(ark_out)
    );

    // Na decriptacao intermediaria, InvMixColumns vem DEPOIS do AddRoundKey.
    minisoc_aes_inv_mix_columns u_inv_mix_columns (
        .state_in (ark_out),
        .state_out(inv_mix_columns_out)
    );

    // Seletor de chave: INIT, nove ROUNDs e FINAL_ROUND.
    // A expansao de chave fornece K[round_sel_o] combinacionalmente.
    always_comb begin
        round_sel_o = 4'd0;
        case (state_fsm_q)
            ST_INIT:        round_sel_o = decrypt_q ? 4'd10 : 4'd0;
            ST_ROUND:       round_sel_o = round_idx_q;
            ST_FINAL_ROUND: round_sel_o = decrypt_q ? 4'd0 : 4'd10;
            default:        round_sel_o = 4'd0;
        endcase
    end

    // Seleciona o estado a ser combinado com a chave de rodada.
    // INIT:                 estado inicial, sem substituicoes.
    // Encrypt ROUND:        SubBytes -> ShiftRows -> MixColumns -> AddRoundKey.
    // Encrypt FINAL_ROUND:  SubBytes -> ShiftRows -> AddRoundKey.
    // Decrypt ROUND/FINAL:  InvShiftRows -> InvSubBytes -> AddRoundKey;
    //                       InvMixColumns e aplicado apenas em ROUND.
    always_comb begin
        ark_in = state_q;
        case (state_fsm_q)
            ST_ROUND: begin
                ark_in = decrypt_q ? inv_sub_bytes_out : mix_columns_out;
            end
            ST_FINAL_ROUND: begin
                ark_in = decrypt_q ? inv_sub_bytes_out : shift_rows_out;
            end
            default: begin
                ark_in = state_q;
            end
        endcase
    end

    assign busy_o = (state_fsm_q != ST_IDLE);

    // Controle sequencial: captura entrada, processa 9 rodadas intermediarias
    // e finaliza sem MixColumns/InvMixColumns na ultima rodada.
    always_ff @(posedge clk_i or negedge rst_n_i) begin
        if (!rst_n_i) begin
            state_fsm_q <= ST_IDLE;
            state_q     <= '0;
            round_idx_q <= 4'd0;
            decrypt_q   <= 1'b0;
            block_o     <= '0;
            done_o      <= 1'b0;
        end else begin
            done_o <= 1'b0;
            case (state_fsm_q)
                ST_IDLE: begin
                    // start_i so e aceito com as 11 round keys disponiveis.
                    if (start_i && keys_valid_i) begin
                        state_q     <= block_i;
                        decrypt_q   <= decrypt_i;
                        round_idx_q <= 4'd0;
                        state_fsm_q <= ST_INIT;
                    end
                end

                ST_INIT: begin
                    // Encrypt: AddRoundKey K0; Decrypt: AddRoundKey K10.
                    state_q      <= ark_out;
                    round_idx_q  <= decrypt_q ? 4'd9 : 4'd1;
                    state_fsm_q  <= ST_ROUND;
                end

                ST_ROUND: begin
                    // Uma rodada intermediaria completa em cada borda.
                    state_q <= decrypt_q ? inv_mix_columns_out : ark_out;
                    if (decrypt_q) begin
                        if (round_idx_q == 4'd1)
                            state_fsm_q <= ST_FINAL_ROUND;
                        else
                            round_idx_q <= round_idx_q - 4'd1;
                    end else begin
                        if (round_idx_q == 4'd9)
                            state_fsm_q <= ST_FINAL_ROUND;
                        else
                            round_idx_q <= round_idx_q + 4'd1;
                    end
                end

                ST_FINAL_ROUND: begin
                    // Encrypt: SubBytes/ShiftRows/AddRoundKey K10.
                    // Decrypt: InvShiftRows/InvSubBytes/AddRoundKey K0.
                    state_q     <= ark_out;
                    block_o     <= ark_out;
                    state_fsm_q <= ST_DONE;
                end

                ST_DONE: begin
                    done_o      <= 1'b1; // Pulso de um ciclo.
                    state_fsm_q <= ST_IDLE;
                end

                default: state_fsm_q <= ST_IDLE;
            endcase
        end
    end
endmodule
