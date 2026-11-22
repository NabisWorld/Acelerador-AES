
 // MiniSoC AES - PLL mock (Semana 5).
 // Clock de referencia: 2 GHz.
 // Divisoes selecionaveis: /1, /2, /4 e /8.
 // Aquisicao pseudoaleatoria de lock: 8 a 23 ciclos de clk_i.
 // Modelo RTL para integracao e verificacao; nao e uma macro fisica de PLL.

module minisoc_pll_mock (
    input  logic       clk_i,
    input  logic       rst_n_i,
    input  logic       pll_enable_i,
    input  logic [1:0] pll_div_sel_i,
    output logic       sys_clk_o,
    output logic       pll_locked_o
);

    // =====================================================
    // 1. Estados de controle
    // =====================================================

    typedef enum logic [1:0] {
        ST_DISABLED,
        ST_ACQUIRING,
        ST_LOCKED
    } pll_state_t;

    pll_state_t state_q;

    // =====================================================
    // 2. Divisor compartilhado e selecao de clock
    // =====================================================

    logic [2:0] div_count_q;
    logic [1:0] div_sel_q;
    logic       selected_clk;

    // Os bits do contador produzem divisoes /2, /4 e /8.
    // O divisor /1 usa a referencia diretamente.
    always_ff @(posedge clk_i or negedge rst_n_i) begin
        if (!rst_n_i)
            div_count_q <= '0;
        else
            div_count_q <= div_count_q + 3'd1;
    end

    always_comb begin
        case (div_sel_q)
            2'b00: selected_clk = clk_i;
            2'b01: selected_clk = div_count_q[0];
            2'b10: selected_clk = div_count_q[1];
            2'b11: selected_clk = div_count_q[2];
            default: selected_clk = 1'b0;
        endcase
    end

    // =====================================================
    // 3. Gerador pseudoaleatorio LFSR
    // =====================================================

    logic [7:0] lfsr_q;

    // Polinomio: x^8 + x^6 + x^5 + x^4 + 1.
    // A seed nao pode ser zero. O LFSR evolui continuamente.
    always_ff @(posedge clk_i or negedge rst_n_i) begin
        if (!rst_n_i)
            lfsr_q <= 8'hA5;
        else
            lfsr_q <= {
                lfsr_q[6:0],
                lfsr_q[7] ^ lfsr_q[5] ^ lfsr_q[4] ^ lfsr_q[3]
            };
    end

    // =====================================================
    // 4. FSM e espera de lock
    // =====================================================

    logic [4:0] lock_target_q;
    logic [4:0] lock_count_q;
    logic       gate_en_q;

    always_ff @(posedge clk_i or negedge rst_n_i) begin
        if (!rst_n_i) begin
            state_q        <= ST_DISABLED;
            div_sel_q      <= 2'b00;
            lock_target_q  <= 5'd8;
            lock_count_q   <= 5'd0;
        end
        else begin
            case (state_q)

                ST_DISABLED: begin
                    // Nova fonte so pode ser selecionada
                    // apos a saida anterior estar bloqueada.
                    if (pll_enable_i && !gate_en_q) begin
                        div_sel_q      <= pll_div_sel_i;
                        lock_target_q  <= 5'd8 + {1'b0, lfsr_q[3:0]};
                        lock_count_q   <= 5'd0;
                        state_q        <= ST_ACQUIRING;
                    end
                end

                ST_ACQUIRING: begin
                    if (!pll_enable_i) begin
                        state_q <= ST_DISABLED;
                    end
                    else if (lock_count_q == (lock_target_q - 5'd1)) begin
                        state_q <= ST_LOCKED;
                    end
                    else begin
                        lock_count_q <= lock_count_q + 5'd1;
                    end
                end

                ST_LOCKED: begin
                    if (!pll_enable_i)
                        state_q <= ST_DISABLED;
                end

                default: begin
                    state_q <= ST_DISABLED;
                end

            endcase
        end
    end

    // LOCK indica aquisicao concluida e clock habilitado.
    // A primeira borda de sys_clk ocorre conforme a
    // fase natural do clock selecionado.
    assign pll_locked_o =
        rst_n_i &&
        pll_enable_i &&
        (state_q == ST_LOCKED) &&
        gate_en_q;

    // =====================================================
    // 5. Clock gating: controle na fase baixa
    // =====================================================

    // Latch de habilitacao do clock.
    // O enable so muda enquanto selected_clk esta baixo.
    // Ao desabilitar durante um nivel alto, o pulso
    // atual termina antes do bloqueio.
    //
    // Em implementacao fisica, devem ser utilizadas
    // celulas dedicadas de clock mux/gating.

    always_latch begin
        if (!rst_n_i)
            gate_en_q = 1'b0;
        else if (!selected_clk)
            gate_en_q = (state_q == ST_LOCKED) && pll_enable_i;
    end

    assign sys_clk_o = selected_clk & gate_en_q;

endmodule
