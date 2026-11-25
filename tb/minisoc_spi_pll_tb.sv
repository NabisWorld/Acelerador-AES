`timescale 1ns/1ps

// MiniSoC AES - Semana 5: integracao SPI Front-End + PLL Mock.
// Testbench funcional: sem AES Engine e sem top-level definitivo.
// SPI Mode 0, MSB-first, 40 bits, 25 MHz. Ref PLL: 2 GHz.
module minisoc_spi_pll_tb;
    logic clk_i = 1'b0;
    logic rst_n_i = 1'b1;
    logic spi_sclk_i = 1'b0;
    logic spi_cs_n_i = 1'b1;
    logic spi_mosi_i = 1'b0;
    logic spi_miso_o;

    logic [127:0] cfg_key_o, cfg_iv_o;
    logic [63:0] cfg_counter_o;
    logic [31:0] cfg_num_blocks_o;
    logic [2:0] cfg_mode_o;
    logic cfg_decrypt_o, aes_start_o;
    logic mem_sel_aes_o, pll_enable_o;
    logic [1:0] pll_div_sel_o;
    logic sys_clk_o, pll_locked_o;

    logic aes_busy_i = 1'b0, aes_done_i = 1'b0, aes_error_i = 1'b0;
    logic [8:0] aes_blocks_done_i = '0;

    localparam logic [5:0] ADDR_SYSTEM_CONTROL = 6'h0E;
    localparam logic [5:0] ADDR_SYSTEM_STATUS  = 6'h0F;
    localparam logic [39:0] NOP = 40'hFE00000000;
    localparam real TOL_NS = 0.005;

    int checks = 0;
    int failures = 0;
    int sys_edges = 0;
    realtime last_sys_rise;

    always #0.25 clk_i = ~clk_i;
    always @(posedge sys_clk_o) begin
        sys_edges = sys_edges + 1;
        last_sys_rise = $realtime;
    end

    minisoc_spi u_spi (
        .clk_i(clk_i), .rst_n_i(rst_n_i),
        .spi_sclk_i(spi_sclk_i), .spi_cs_n_i(spi_cs_n_i),
        .spi_mosi_i(spi_mosi_i), .spi_miso_o(spi_miso_o),
        .cfg_key_o(cfg_key_o), .cfg_iv_o(cfg_iv_o),
        .cfg_counter_o(cfg_counter_o), .cfg_num_blocks_o(cfg_num_blocks_o),
        .cfg_mode_o(cfg_mode_o), .cfg_decrypt_o(cfg_decrypt_o),
        .aes_start_o(aes_start_o), .aes_busy_i(aes_busy_i),
        .aes_done_i(aes_done_i), .aes_error_i(aes_error_i),
        .aes_blocks_done_i(aes_blocks_done_i),
        .mem_sel_aes_o(mem_sel_aes_o), .pll_enable_o(pll_enable_o),
        .pll_div_sel_o(pll_div_sel_o), .pll_locked_i(pll_locked_o)
    );

    minisoc_pll_mock u_pll (
        .clk_i(clk_i), .rst_n_i(rst_n_i),
        .pll_enable_i(pll_enable_o),
        .pll_div_sel_i(pll_div_sel_o),
        .sys_clk_o(sys_clk_o), .pll_locked_o(pll_locked_o)
    );

    function automatic logic [39:0] frame(
        input logic rwb,
        input logic [5:0] addr,
        input logic [31:0] data
    );
        return {rwb, addr, 1'b0, data};
    endfunction

    task automatic check(input string name, input logic ok);
        checks++;
        if (ok === 1'b1)
            $display("[PASS] %s", name);
        else begin
            failures++;
            $display("[FAIL] %s - t=%0t", name, $time);
        end
    endtask

    // Cada bit: MOSI configurado no nivel baixo, MISO amostrado na subida.
    // Um quadro completo leva 1600 ns (40 bits x 40 ns).
    task automatic spi_transfer(
        input logic [39:0] tx,
        output logic [39:0] rx
    );
        rx = '0;
        spi_cs_n_i = 1'b0;
        #2.3;
        for (int b = 39; b >= 0; b--) begin
            spi_mosi_i = tx[b];
            #20;
            rx = {rx[38:0], spi_miso_o};
            spi_sclk_i = 1'b1;
            #20 spi_sclk_i = 1'b0;
        end
        #1 spi_cs_n_i = 1'b1;
        spi_mosi_i = 1'b0;
        #3;
    endtask

    task automatic spi_write(input logic [5:0] addr, input logic [31:0] data);
        logic [39:0] rx;
        spi_transfer(frame(1'b0, addr, data), rx);
        check($sformatf("MISO zero durante WRITE 0x%02h", addr), rx === 40'd0);
    endtask

    task automatic spi_read(input logic [5:0] addr, output logic [31:0] data);
        logic [39:0] rx;
        spi_transfer(frame(1'b1, addr, 32'd0), rx);
        check($sformatf("MISO zero durante READ request 0x%02h", addr),
              rx === 40'd0);
        spi_transfer(NOP, rx);
        check($sformatf("Cabecalho MISO zero no READ 0x%02h", addr),
              rx[39:32] === 8'h00);
        data = rx[31:0];
    endtask

    task automatic expect_register(
        input logic [5:0] addr,
        input logic [31:0] expected,
        input string name
    );
        logic [31:0] data;
        spi_read(addr, data);
        check(name, data === expected);
        if (data !== expected)
            $display("       recebido=%08h esperado=%08h", data, expected);
    endtask

    task automatic check_stopped(input string name);
        int previous;
        // Permite encerrar eventual ultimo pulso na fase alta.
        #8;
        previous = sys_edges;
        #8;
        check(name, (sys_clk_o === 1'b0) &&
                    (pll_locked_o === 1'b0) && (sys_edges == previous));
    endtask

    task automatic measure_period(input real expected_ns, input string name);
        realtime t0, t1, tfall;
        real t_period, t_high, t_low;
        logic good;
        good = 1'b1;
        @(posedge sys_clk_o) t0 = $realtime;
        for (int n = 0; n < 5; n++) begin
            @(negedge sys_clk_o) tfall = $realtime;
            @(posedge sys_clk_o) t1 = $realtime;
            t_period = t1-t0;
            t_high = tfall-t0;
            t_low = t1-tfall;
            if (t_period < expected_ns-TOL_NS ||
                t_period > expected_ns+TOL_NS ||
                t_high < expected_ns/2.0-TOL_NS ||
                t_high > expected_ns/2.0+TOL_NS ||
                t_low < expected_ns/2.0-TOL_NS ||
                t_low > expected_ns/2.0+TOL_NS) begin
                good = 1'b0;
                $display("[DETALHE] %s: periodo=%0.3f alto=%0.3f baixo=%0.3f ns",
                         name, t_period, t_high, t_low);
            end
            t0 = t1;
        end
        check(name, good);
    endtask

    initial begin : run_tests
        logic [31:0] value;
        logic [31:0] ctrl;

        $display("============================================================");
        $display(" MiniSoC AES - Testbench Integrado SPI + PLL - Semana 5");
        $display("============================================================");

        rst_n_i = 1'b0;
        #3.1 rst_n_i = 1'b1;
        #2;

        $display("\n[TESTE 01] Reset e status inicial via SPI");
        check_stopped("PLL desabilitado apos reset");
        expect_register(ADDR_SYSTEM_CONTROL, 32'd0,
                        "SYSTEM_CONTROL = 0 apos reset");
        expect_register(ADDR_SYSTEM_STATUS, 32'd0,
                        "SYSTEM_STATUS.LOCKED = 0 apos reset");

        // Percorre todos os divisores, sempre configurando via SPI.
        for (int d = 0; d < 4; d++) begin
            $display("\n[TESTE %02d] PLL /%0d configurado via SPI", d+2, 1 << d);
            ctrl = (32'(d) << 2) | 32'h2; // PLL_ENABLE=1, MEM_SEL_AES=0.
            spi_write(ADDR_SYSTEM_CONTROL, ctrl);
            check("Enable e divisor chegaram ao PLL",
                  pll_enable_o === 1'b1 && pll_div_sel_o === 2'(d));
            expect_register(ADDR_SYSTEM_CONTROL, ctrl,
                            "SYSTEM_CONTROL reflete configuracao escrita");
            // A aquisicao dura ~4-12 ns e uma leitura SPI leva ~3,2 us.
            // Portanto esta consulta verifica LOCKED estavel, nao o instante
            // de sua subida. Esse instante foi coberto no TB individual.
            expect_register(ADDR_SYSTEM_STATUS, 32'h1,
                            "SYSTEM_STATUS indica lock pelo SPI");
            check("PLL locked e clock habilitado",
                  pll_locked_o === 1'b1 && sys_clk_o !== 1'bx);
            measure_period(0.5 * (1 << d),
                           $sformatf("Periodo e duty cycle de sys_clk /%0d", 1 << d));

            spi_write(ADDR_SYSTEM_CONTROL, 32'd0);
            check_stopped("sys_clk bloqueado apos disable pelo SPI");
            expect_register(ADDR_SYSTEM_STATUS, 32'd0,
                            "SYSTEM_STATUS indica unlock pelo SPI");
        end

        $display("\n[TESTE 06] Mudanca de divisor sem desabilitar PLL");
        spi_write(ADDR_SYSTEM_CONTROL, 32'h6); // /2, enable=1.
        expect_register(ADDR_SYSTEM_STATUS, 32'h1, "Lock /2 ativo");
        measure_period(1.0, "Clock inicialmente /2");
        spi_write(ADDR_SYSTEM_CONTROL, 32'hE); // Solicita /8, enable=1.
        check("Registro recebe a nova selecao /8", pll_div_sel_o === 2'b11);
        measure_period(1.0, "Clock permanece /2 ate desabilitacao");
        spi_write(ADDR_SYSTEM_CONTROL, 32'd0);
        check_stopped("PLL desligado antes de adotar /8");
        spi_write(ADDR_SYSTEM_CONTROL, 32'hE);
        expect_register(ADDR_SYSTEM_STATUS, 32'h1, "Lock readquirido em /8");
        measure_period(4.0, "Clock passa a /8 apos nova habilitacao");

        $display("\n[TESTE 07] Reset global com PLL habilitado");
        rst_n_i = 1'b0;
        #0.001;
        check("Reset bloqueia clock e lock",
              sys_clk_o === 1'b0 && pll_locked_o === 1'b0);
        #3 rst_n_i = 1'b1;
        check_stopped("Clock permanece bloqueado apos reset");
        expect_register(ADDR_SYSTEM_CONTROL, 32'd0,
                        "Controle retorna ao reset");
        expect_register(ADDR_SYSTEM_STATUS, 32'd0,
                        "Status retorna ao reset");
        spi_write(ADDR_SYSTEM_CONTROL, 32'h2);
        expect_register(ADDR_SYSTEM_STATUS, 32'h1,
                        "SPI reabilita PLL apos reset");
        measure_period(0.5, "Clock /1 recuperado apos reset");
        spi_write(ADDR_SYSTEM_CONTROL, 32'd0);
        check_stopped("Desligamento final");

        $display("\n============================================================");
        $display(" Resultado do Testbench Integrado SPI + PLL");
        $display("============================================================");
        $display("Verificacoes : %0d", checks);
        $display("Falhas       : %0d", failures);
        if (failures != 0)
            $fatal(1, "FAIL: %0d verificacoes falharam", failures);
        else
            $display("PASS: minisoc_spi_pll_tb - todas as verificacoes passaram");
        $finish;
    end

    initial begin
        #100000;
        $fatal(1, "FAIL: timeout global no testbench integrado");
    end
endmodule
