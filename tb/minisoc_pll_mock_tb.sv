
`timescale 1ns/1ps

// ============================================================================
// MiniSoC AES - Semana 5
// Testbench dirigido e autochecking do minisoc_pll_mock.
//
// Referencia: 2 GHz (periodo de 0,5 ns).
// Divisores: /1, /2, /4 e /8.
// Verificacoes: reset, aquisicao, lock, periodo, duty cycle, gating,
// desabilitacao segura, reabilitacao e selecao de divisor.
//
// A leitura de lock_target_q e uma verificacao WHITE-BOX da decisao local
// de microarquitetura (LFSR + espera de 8 a 23 ciclos).
// ============================================================================

module minisoc_pll_mock_tb;

    logic       clk_i         = 1'b0;
    logic       rst_n_i       = 1'b1;
    logic       pll_enable_i  = 1'b0;
    logic [1:0] pll_div_sel_i = 2'b00;
    logic       sys_clk_o;
    logic       pll_locked_o;

    int checks = 0;
    int errors = 0;
    int sys_rises = 0;
    int ref_rises = 0;
    bit [23:0] targets_seen = '0;
    int unique_targets = 0;

    // Periodos calculados a partir do clock de referencia de 2 GHz.
    real expected_period [0:3] = '{0.5, 1.0, 2.0, 4.0};
    localparam real TOL = 0.005;  // 5 ps, resolucao da simulacao: 1 ps.

    minisoc_pll_mock dut (
        .clk_i          (clk_i),
        .rst_n_i        (rst_n_i),
        .pll_enable_i   (pll_enable_i),
        .pll_div_sel_i  (pll_div_sel_i),
        .sys_clk_o      (sys_clk_o),
        .pll_locked_o   (pll_locked_o)
    );

    // Clock de referencia: 2 GHz.
    always #0.25 clk_i = ~clk_i;

    always @(posedge clk_i)
        ref_rises = ref_rises + 1;

    // Nenhuma NOVA borda de subida pode ocorrer antes do lock.
    // Na desabilitacao durante a fase alta, o pulso em andamento pode
    // terminar normalmente; por isso nao proibimos a borda de descida.
    always @(posedge sys_clk_o) begin
        sys_rises = sys_rises + 1;
        if (rst_n_i === 1'b1 &&
            (pll_enable_i !== 1'b1 || pll_locked_o !== 1'b1)) begin
            errors = errors + 1;
            $display("[FAIL] Borda de sys_clk sem enable/lock em t=%0t", $time);
        end
    end

    task automatic check(input string description, input logic condition);
        checks = checks + 1;
        if (condition === 1'b1)
            $display("[PASS] %s", description);
        else begin
            errors = errors + 1;
            $display("[FAIL] %s (t=%0t)", description, $time);
        end
    endtask

    // Verifica valor estavel e ausencia de bordas durante varios ciclos.
    task automatic check_stopped(input string description, input int cycles);
        int before_rises;
        before_rises = sys_rises;
        repeat (cycles) @(negedge clk_i);
        #0.001;
        check(description,
              (sys_clk_o === 1'b0) &&
              (pll_locked_o === 1'b0) &&
              (sys_rises == before_rises));
    endtask

    task automatic reset_dut;
        pll_enable_i = 1'b0;
        pll_div_sel_i = 2'b00;
        rst_n_i = 1'b0;
        #1.1;
        rst_n_i = 1'b1;
        #0.1;
    endtask

    // Aguarda lock com timeout e verifica a faixa de latencia externa.
    // A FSM espera 8..23 ciclos; o gate pode exigir mais ate 8 ciclos
    // adicionais para abrir durante a fase baixa (divisor /8).
    task automatic enable_and_wait(input logic [1:0] div_sel);
        int ref_before;
        bit found;
        int target;

        pll_div_sel_i = div_sel;
        pll_enable_i  = 1'b1;
        ref_before = ref_rises;
        found = 1'b0;

        // Amostragem na negedge evita corrida com os nonblocking assignments.
        for (int i = 0; i < 45; i++) begin
            @(negedge clk_i);
            #0.001;
            if (pll_locked_o === 1'b1) begin
                found = 1'b1;
                break;
            end
            if (sys_clk_o !== 1'b0) begin
                errors = errors + 1;
                $display("[FAIL] sys_clk ativo antes do lock (div=%0d)", div_sel);
            end
        end

        check($sformatf("Lock adquirido com divisor /%0d", 1 << div_sel), found);
        if (!found)
            $fatal(1, "Timeout aguardando pll_locked_o");

        // +1 ciclo pela entrada na FSM; atraso extra pela fase segura.
        check($sformatf("Latencia externa do lock /%0d (%0d ciclos)",
                        1 << div_sel, ref_rises-ref_before),
              (ref_rises-ref_before >= 8) &&
              (ref_rises-ref_before <= 33));

        // O status corrigido so pode subir quando o gate esta habilitado.
        check("LOCK confirmado apenas com gate habilitado",
              dut.gate_en_q === 1'b1);

        // Verificacao white-box da escolha documentada (nao do Block Guide).
        target = int'(dut.lock_target_q);
        check($sformatf("Alvo interno do LFSR = %0d ciclos", target),
              (target >= 8) && (target <= 23));
        check("Contador concluiu a espera programada",
              int'(dut.lock_count_q) == (target - 1));
        if (target >= 8 && target <= 23 && !targets_seen[target]) begin
            targets_seen[target] = 1'b1;
            unique_targets = unique_targets + 1;
        end
    endtask

    // Mede periodo, tempo alto e tempo baixo por varios ciclos completos.
    task automatic measure_clock(input real period_ns, input string description);
        realtime last_rise;
        realtime fall_time;
        realtime new_rise;
        real measured_period;
        real measured_high;
        real measured_low;
        bit good;

        good = 1'b1;
        @(posedge sys_clk_o);
        last_rise = $realtime;

        for (int i = 0; i < 6; i++) begin
            @(negedge sys_clk_o);
            fall_time = $realtime;
            @(posedge sys_clk_o);
            new_rise = $realtime;

            measured_period = new_rise - last_rise;
            measured_high   = fall_time - last_rise;
            measured_low    = new_rise - fall_time;

            if ((measured_period < period_ns - TOL) ||
                (measured_period > period_ns + TOL) ||
                (measured_high < period_ns/2.0 - TOL) ||
                (measured_high > period_ns/2.0 + TOL) ||
                (measured_low < period_ns/2.0 - TOL) ||
                (measured_low > period_ns/2.0 + TOL)) begin
                good = 1'b0;
                $display("[DETALHE] %s: periodo=%0.3f alto=%0.3f baixo=%0.3f ns",
                         description, measured_period, measured_high, measured_low);
            end
            last_rise = new_rise;
        end
        check(description, good);
    endtask

    // Desabilita propositalmente na fase alta. O pulso atual nao
    // deve ser encurtado, e nenhuma nova borda pode surgir depois.
    task automatic disable_during_high(input real period_ns);
        realtime rise_t;
        realtime fall_t;
        int rises_after_fall;

        @(posedge sys_clk_o);
        rise_t = $realtime;
        #0.05 pll_enable_i = 1'b0;

        // Aguarda a atualizacao da logica combinacional.
        #0.001;

        check("LOCK cai imediatamente com enable=0",
            pll_locked_o === 1'b0);

        @(negedge sys_clk_o);
        fall_t = $realtime;
        check("Pulso alto termina sem truncamento",
              ((fall_t-rise_t) >= period_ns/2.0 - TOL) &&
              ((fall_t-rise_t) <= period_ns/2.0 + TOL));

        rises_after_fall = sys_rises;
        repeat (22) @(negedge clk_i);
        #0.001;
        check("Clock bloqueado apos desabilitacao",
              (sys_clk_o === 1'b0) &&
              (pll_locked_o === 1'b0) &&
              (sys_rises == rises_after_fall));
    endtask

    initial begin : tests
        $display("============================================================");
        $display(" MiniSoC AES - Testbench PLL Mock - Semana 5");
        $display("============================================================");

        // TESTE 01 - Reset e bloqueio inicial.
        $display("\n[TESTE 01] Reset e PLL desabilitado");
        #0.1;
        reset_dut();
        check_stopped("Saida bloqueada apos reset", 24);

        // TESTE 02 - Habilitacao interrompida durante a aquisicao.
        $display("\n[TESTE 02] Disable antes da aquisicao de lock");
        pll_div_sel_i = 2'b10;
        pll_enable_i = 1'b1;
        repeat (3) @(negedge clk_i);
        #0.001;
        check("Sem lock antes do minimo de 8 ciclos",
              (pll_locked_o === 1'b0) && (sys_clk_o === 1'b0));
        pll_enable_i = 1'b0;
        check_stopped("Interrupcao da aquisicao mantem a saida bloqueada", 30);

        // TESTES 03..06 - Quatro divisores e desligamento na fase alta.
        for (int d = 0; d < 4; d++) begin
            $display("\n[TESTE %02d] PLL /%0d", d+3, 1 << d);
            enable_and_wait(2'(d));
            measure_clock(expected_period[d],
                          $sformatf("Periodo e duty-cycle corretos em /%0d", 1 << d));
            disable_during_high(expected_period[d]);
        end

        // TESTE 07 - Reconfiguracao com enable ativo (divisor capturado).
        $display("\n[TESTE 07] Seletor alterado com PLL ligado");
        enable_and_wait(2'b01);
        measure_clock(1.0, "Divisor /2 inicial");
        pll_div_sel_i = 2'b11;
        measure_clock(1.0, "Divisor permanece /2 enquanto habilitado");
        disable_during_high(1.0);
        enable_and_wait(2'b11);
        measure_clock(4.0, "Divisor /8 adotado somente na nova habilitacao");
        disable_during_high(4.0);

        // TESTE 08 - Variacao da espera pseudoaleatoria entre habilitacoes.
        $display("\n[TESTE 08] Variacao pseudoaleatoria da aquisicao");
        for (int k = 0; k < 8; k++) begin
            // Intervalo variavel: o LFSR continua evoluindo com PLL desligado.
            repeat (k+2) @(negedge clk_i);
            enable_and_wait(2'b00);
            disable_during_high(0.5);
        end
        check($sformatf("LFSR produziu %0d alvos distintos", unique_targets),
              unique_targets >= 2);

        // TESTE 09 - Reset global durante o funcionamento.
        $display("\n[TESTE 09] Reset global durante a operacao");
        enable_and_wait(2'b10);
        measure_clock(2.0, "Clock /4 antes do reset global");
        #0.05 rst_n_i = 1'b0;
        #0.001;
        check("Reset global bloqueia clock e apaga lock",
              (sys_clk_o === 1'b0) && (pll_locked_o === 1'b0));
        pll_enable_i = 1'b0;
        check_stopped("Sem novos pulsos durante reset", 24);
        rst_n_i = 1'b1;
        check_stopped("Sem pulsos apos reset com enable=0", 16);

        $display("\n============================================================");
        $display(" Resultado do Testbench PLL Mock");
        $display("============================================================");
        $display("Total de verificacoes : %0d", checks);
        $display("Total de falhas       : %0d", errors);
        if (errors != 0)
            $fatal(1, "FAIL: minisoc_pll_mock_tb encontrou %0d falha(s)", errors);
        else
            $display("PASS: minisoc_pll_mock_tb - todas as verificacoes passaram");
        $finish;
    end

    // Timeout global para nao deixar o VCS travado.
    initial begin
        #5000;
        $fatal(1, "FAIL: timeout global do minisoc_pll_mock_tb");
    end

endmodule
