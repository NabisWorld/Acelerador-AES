`timescale 1ns/1ps

// ============================================================================
// MiniSoC AES - Semana 5
// Testbench dirigido e autochecking do SPI Front-End.
//
// Base: minisoc_spi_tb.sv (primeiro testbench).
// Melhorias incorporadas de minisoc_spi_tb2.sv:
//   - conexoes explicitas com o DUT;
//   - organizacao dos cenarios por secoes numeradas;
//   - verificacoes tipadas de 32, 64 e 128 bits;
//   - registro de PASS/FAIL e consolidacao das falhas ao final.
//
// Convencoes da microarquitetura atual (a confirmar com o verificador):
//   - SPI Mode 0, MSB-first, 25 MHz;
//   - NOP de retorno: RWb=1, ADDR=6'h3F, RSV=0 (header 8'hFE);
//   - MISO da segunda transacao: {8'h00, DATA[31:0]};
//   - registrador VERSION: 32'h0001_0000.
//
// Os status do AES e do PLL sao fornecidos pelo testbench. Este teste NAO
// verifica a frequencia nem o lock de um PLL real/integrado.
// ============================================================================

module minisoc_spi_tb;

    // ========================================================================
    // 1. Clocks, reset e interface com o DUT
    // ========================================================================

    logic         clk_i = 1'b0;
    logic         rst_n_i = 1'b1;
    logic         spi_sclk_i = 1'b0;
    logic         spi_cs_n_i = 1'b1;
    logic         spi_mosi_i = 1'b0;
    logic         spi_miso_o;

    logic [127:0] cfg_key_o;
    logic [127:0] cfg_iv_o;
    logic [63:0]  cfg_counter_o;
    logic [31:0]  cfg_num_blocks_o;
    logic [2:0]   cfg_mode_o;
    logic         cfg_decrypt_o;
    logic         aes_start_o;

    logic         aes_busy_i = 1'b0;
    logic         aes_done_i = 1'b0;
    logic         aes_error_i = 1'b0;
    logic [8:0]   aes_blocks_done_i = 9'd0;

    logic         mem_sel_aes_o;
    logic         pll_enable_o;
    logic [1:0]   pll_div_sel_o;
    logic         pll_locked_i = 1'b0;

    localparam logic [31:0] EXPECTED_VERSION = 32'h0001_0000;
    localparam logic [39:0] NOP_FRAME = 40'hFE00000000;

    int checks = 0;
    int errors = 0;
    int start_pulses = 0;
    logic prev_start = 1'b0;

    logic [31:0] pattern [0:10];
    logic [39:0] response;
    int pulses_before;

    // Clock always-on: 2 GHz, periodo de 0,5 ns.
    always #0.25 clk_i = ~clk_i;

    // Conexoes explicitas: evitam acoplamentos acidentais pelo nome do sinal.
    minisoc_spi dut (
        .clk_i              (clk_i),
        .rst_n_i            (rst_n_i),
        .spi_sclk_i         (spi_sclk_i),
        .spi_cs_n_i         (spi_cs_n_i),
        .spi_mosi_i         (spi_mosi_i),
        .spi_miso_o         (spi_miso_o),
        .cfg_key_o          (cfg_key_o),
        .cfg_iv_o           (cfg_iv_o),
        .cfg_counter_o      (cfg_counter_o),
        .cfg_num_blocks_o   (cfg_num_blocks_o),
        .cfg_mode_o         (cfg_mode_o),
        .cfg_decrypt_o      (cfg_decrypt_o),
        .aes_start_o        (aes_start_o),
        .aes_busy_i         (aes_busy_i),
        .aes_done_i         (aes_done_i),
        .aes_error_i        (aes_error_i),
        .aes_blocks_done_i  (aes_blocks_done_i),
        .mem_sel_aes_o      (mem_sel_aes_o),
        .pll_enable_o       (pll_enable_o),
        .pll_div_sel_o      (pll_div_sel_o),
        .pll_locked_i       (pll_locked_i)
    );

    // Monitora START no meio do ciclo always-on, evitando a regiao NBA.
    // Mantem a verificacao do primeiro TB: START nao pode durar > 1 ciclo.
    always @(negedge clk_i) begin
        if (!rst_n_i) begin
            prev_start   = 1'b0;
            start_pulses = 0;
        end
        else begin
            if ((aes_start_o === 1'b1) && (prev_start === 1'b1)) begin
                errors = errors + 1;
                $display("[FAIL] START durou mais de um ciclo de clk_i em t=%0t", $time);
            end
            if (aes_start_o === 1'b1)
                start_pulses = start_pulses + 1;
            prev_start = aes_start_o;
        end
    end

    // ========================================================================
    // 2. Funcoes e tarefas de verificacao
    // ========================================================================

    function automatic logic [39:0] make_frame(
        input logic rwb,
        input logic [5:0] addr,
        input logic rsv,
        input logic [31:0] data
    );
        return {rwb, addr, rsv, data};
    endfunction

    task automatic check(input logic condition, input string description);
        checks = checks + 1;
        if (condition !== 1'b1) begin
            errors = errors + 1;
            $display("[FAIL] %s", description);
        end
        else
            $display("[PASS] %s", description);
    endtask

    task automatic check32(
        input string description,
        input logic [31:0] got,
        input logic [31:0] expected
    );
        checks = checks + 1;
        if (got !== expected) begin
            errors = errors + 1;
            $display("[FAIL] %s: recebido=%08h esperado=%08h", description, got, expected);
        end
        else
            $display("[PASS] %s = %08h", description, got);
    endtask

    task automatic check64(
        input string description,
        input logic [63:0] got,
        input logic [63:0] expected
    );
        checks = checks + 1;
        if (got !== expected) begin
            errors = errors + 1;
            $display("[FAIL] %s: recebido=%016h esperado=%016h", description, got, expected);
        end
        else
            $display("[PASS] %s = %016h", description, got);
    endtask

    task automatic check128(
        input string description,
        input logic [127:0] got,
        input logic [127:0] expected
    );
        checks = checks + 1;
        if (got !== expected) begin
            errors = errors + 1;
            $display("[FAIL] %s: recebido=%032h esperado=%032h", description, got, expected);
        end
        else
            $display("[PASS] %s = %032h", description, got);
    endtask

    task automatic check40(
        input string description,
        input logic [39:0] got,
        input logic [39:0] expected
    );
        checks = checks + 1;
        if (got !== expected) begin
            errors = errors + 1;
            $display("[FAIL] %s: recebido=%010h esperado=%010h", description, got, expected);
        end
        else
            $display("[PASS] %s = %010h", description, got);
    endtask

    // ========================================================================
    // 3. Mestre SPI: transacoes Mode 0, MSB-first e 25 MHz
    // ========================================================================

    // Nao controla CS: permite testar frames parciais e 80 bits no mesmo CS.
    // Mantem a amostragem de MISO ANTES da subida, como no primeiro TB,
    // e confere se o valor permanece estavel apos essa subida.
    task automatic transfer_bits(
        input logic [39:0] frame,
        input int nbits,
        output logic [39:0] received
    );
        logic miso_at_edge;
        received = '0;
        for (int i = 39; i >= 40-nbits; i--) begin
            spi_mosi_i = frame[i];
            #20 begin
                miso_at_edge = spi_miso_o;
                spi_sclk_i = 1'b1;
                received = {received[38:0], miso_at_edge};
            end
            #1 if (spi_miso_o !== miso_at_edge) begin
                errors = errors + 1;
                $display("[FAIL] MISO mudou na borda de subida (bit %0d, t=%0t)", i, $time);
            end
            #19 spi_sclk_i = 1'b0;
        end
    endtask

    task automatic select_spi;
        spi_cs_n_i = 1'b0;
        #2.3 spi_mosi_i = 1'b0; // Tempo de CS setup; fase nao alinhada a clk_i.
    endtask

    task automatic deselect_spi;
        #1 spi_cs_n_i = 1'b1;
        spi_mosi_i = 1'b0;
        #2 if (spi_miso_o !== 1'b0) begin
            errors = errors + 1;
            $display("[FAIL] MISO deveria estar em zero fora da transacao");
        end
    endtask

    task automatic spi_transaction(
        input logic [39:0] frame,
        output logic [39:0] received
    );
        select_spi();
        transfer_bits(frame, 40, received);
        deselect_spi();
    endtask

    task automatic spi_write(input logic [5:0] addr, input logic [31:0] data);
        logic [39:0] ignored;
        spi_transaction(make_frame(1'b0, addr, 1'b0, data), ignored);
        if (ignored !== 40'd0) begin
            errors = errors + 1;
            $display("[FAIL] MISO nao nulo durante escrita em %02h: %010h", addr, ignored);
        end
    endtask

    task automatic read_request(input logic [5:0] addr);
        logic [39:0] ignored;
        // DATA da primeira transacao de leitura deve ser ignorado pelo DUT.
        spi_transaction(make_frame(1'b1, addr, 1'b0, 32'hA5A5_A5A5), ignored);
        if (ignored !== 40'd0) begin
            errors = errors + 1;
            $display("[FAIL] MISO nao nulo na solicitacao READ %02h: %010h", addr, ignored);
        end
    endtask

    task automatic expect_nop(input logic [31:0] expected, input string description);
        logic [39:0] received;
        spi_transaction(NOP_FRAME, received);
        check40(description, received, {8'h00, expected});
    endtask

    task automatic expect_read(input logic [5:0] addr, input logic [31:0] expected);
        read_request(addr);
        expect_nop(expected, $sformatf("READ 0x%02h = 0x%08h", addr, expected));
    endtask

    task automatic reset_dut;
        // Reset real com SCLK parado; reset do DUT nao depende de SCLK.
        spi_cs_n_i = 1'b1;
        spi_sclk_i = 1'b0;
        spi_mosi_i = 1'b0;
        rst_n_i = 1'b0;
        #4 rst_n_i = 1'b1;
        #3.1 spi_mosi_i = 1'b0;
    endtask

    // ========================================================================
    // 4. Execucao dos cenarios dirigidos
    // ========================================================================

    initial begin : run_tests
        #1 reset_dut();

        $display("============================================================");
        $display(" MiniSoC AES - SPI Front-End - Testbench Semana 5");
        $display("============================================================");

        // --------------------------------------------------------------------
        // TESTE 01 - Reset e leituras iniciais
        // --------------------------------------------------------------------
        $display("\n[TESTE 01] Reset e leituras iniciais");
        check({cfg_key_o, cfg_iv_o, cfg_counter_o, cfg_num_blocks_o,
               cfg_mode_o, cfg_decrypt_o, aes_start_o, mem_sel_aes_o,
               pll_enable_o, pll_div_sel_o} === '0,
              "Reset das configuracoes");
        expect_nop(32'd0, "NOP sem leitura apos reset");
        expect_read(6'h0D, EXPECTED_VERSION);
        expect_read(6'h0A, 32'd0);
        expect_read(6'h0E, 32'd0);

        // --------------------------------------------------------------------
        // TESTE 02 - Todos os registradores de dados R/W: 0x00 a 0x0A
        // --------------------------------------------------------------------
        $display("\n[TESTE 02] Escrita e leitura de KEY, IV, COUNTER e NUM_BLOCKS");
        pattern[0]  = 32'h81234567;
        pattern[1]  = 32'h89ABCDEF;
        pattern[2]  = 32'h10203040;
        pattern[3]  = 32'hF1E2D3C5;
        pattern[4]  = 32'h00112233;
        pattern[5]  = 32'h44556677;
        pattern[6]  = 32'h8899AABB;
        pattern[7]  = 32'hCCDDEEFF;
        pattern[8]  = 32'hBADC0FFE;
        pattern[9]  = 32'h01234569;
        pattern[10] = 32'd256;

        for (int i = 0; i <= 10; i++)
            spi_write(6'(i), pattern[i]);
        for (int i = 0; i <= 10; i++)
            expect_read(6'(i), pattern[i]);

        check128("Ordem KEY0..KEY3 nas saidas", cfg_key_o,
                 {pattern[0], pattern[1], pattern[2], pattern[3]});
        check128("Ordem IV0..IV3 nas saidas", cfg_iv_o,
                 {pattern[4], pattern[5], pattern[6], pattern[7]});
        check64("Ordem COUNTER_HI/LO nas saidas", cfg_counter_o,
                {pattern[8], pattern[9]});
        check32("NUM_BLOCKS = 256 sem truncamento", cfg_num_blocks_o, 32'd256);

        spi_write(6'h0A, 32'h8000_0201);
        expect_read(6'h0A, 32'h8000_0201);
        check32("Preservacao integral de NUM_BLOCKS invalido", cfg_num_blocks_o,
                32'h8000_0201);

        // --------------------------------------------------------------------
        // TESTE 03 - AES_CONTROL: mascara, MODE, DECRYPT e START
        // --------------------------------------------------------------------
        $display("\n[TESTE 03] AES_CONTROL e pulso START");
        pulses_before = start_pulses;
        spi_write(6'h0B, 32'hFFFF_FFF6); // MODE=101, DECRYPT=1, START=0.
        expect_read(6'h0B, 32'h0000_0016);
        check(cfg_mode_o === 3'b101 && cfg_decrypt_o === 1'b1,
              "Campos MODE e DECRYPT");
        check(start_pulses == pulses_before,
              "Escrita de START=0 nao gera pulso");

        spi_write(6'h0B, 32'h0000_0017);
        check(start_pulses == pulses_before+1 && aes_start_o === 1'b0,
              "START=1 gera um unico pulso de clk_i");
        expect_read(6'h0B, 32'h0000_0016);
        check(start_pulses == pulses_before+1,
              "Leitura de AES_CONTROL nao gera START");
        spi_write(6'h0B, 32'h0000_0017);
        check(start_pulses == pulses_before+2,
              "Segunda escrita START=1 gera novo pulso");

        // --------------------------------------------------------------------
        // TESTE 04 - SYSTEM_CONTROL: todos os divisores e sinais de controle
        // --------------------------------------------------------------------
        $display("\n[TESTE 04] SYSTEM_CONTROL e quatro selecoes de divisor");
        // Testa configuracao SPI; nao testa frequencia/lock do PLL.
        for (int d = 0; d < 4; d++) begin
            spi_write(6'h0E, 32'hFFFF_FFF3 | (32'(d) << 2));
            expect_read(6'h0E, 32'h0000_0003 | (32'(d) << 2));
            check(pll_div_sel_o === 2'(d) &&
                  pll_enable_o === 1'b1 && mem_sel_aes_o === 1'b1,
                  $sformatf("Saidas SYSTEM_CONTROL divisor %0d", d));
        end
        spi_write(6'h0E, 32'd0);
        expect_read(6'h0E, 32'd0);
        check(pll_enable_o === 1'b0 && mem_sel_aes_o === 1'b0,
              "Desabilitacao PLL e ownership externo");

        // --------------------------------------------------------------------
        // TESTE 05 - Status simulados e protecao dos registradores R
        // --------------------------------------------------------------------
        $display("\n[TESTE 05] AES_STATUS, SYSTEM_STATUS e VERSION protegidos");
        aes_blocks_done_i = 9'd256;
        aes_error_i = 1'b1;
        aes_done_i = 1'b1;
        aes_busy_i = 1'b1;
        pll_locked_i = 1'b1;
        expect_read(6'h0C, 32'h0000_0807);
        expect_read(6'h0F, 32'd1);

        spi_write(6'h0C, 32'd0);
        spi_write(6'h0D, 32'hDEAD_BEEF);
        spi_write(6'h0F, 32'd0);
        expect_read(6'h0C, 32'h0000_0807);
        expect_read(6'h0D, EXPECTED_VERSION);
        expect_read(6'h0F, 32'd1);
        pll_locked_i = 1'b0;
        expect_read(6'h0F, 32'd0);
        aes_blocks_done_i = 9'd0;
        aes_error_i = 1'b0;
        aes_done_i = 1'b0;
        aes_busy_i = 1'b0;
        expect_read(6'h0C, 32'd0);

        // --------------------------------------------------------------------
        // TESTE 06 - Snapshot: status muda entre READ e durante o NOP
        // --------------------------------------------------------------------
        $display("\n[TESTE 06] Resposta de leitura estavel durante NOP");
        aes_blocks_done_i = 9'd17;
        aes_busy_i = 1'b1;
        read_request(6'h0C);
        aes_blocks_done_i = 9'd18;
        fork
            begin
                #600 aes_blocks_done_i = 9'd19;
                aes_done_i = 1'b1;
            end
            begin
                expect_nop(32'h0000_0089,
                           "Snapshot de AES_STATUS estavel durante NOP");
            end
        join
        expect_nop(32'd0, "Segundo NOP nao repete resposta consumida");
        expect_read(6'h0C, 32'h0000_009B);

        // --------------------------------------------------------------------
        // TESTE 07 - Frame incompleto, RSV invalido, endereco nao mapeado
        // --------------------------------------------------------------------
        $display("\n[TESTE 07] Frames incompletos, RSV invalido e endereco ausente");
        select_spi();
        transfer_bits(make_frame(1'b0, 6'h00, 1'b0, 32'hDEAD_BEEF), 39, response);
        deselect_spi();
        expect_read(6'h00, pattern[0]);

        spi_transaction(make_frame(1'b0, 6'h00, 1'b1, 32'hDEAD_BEEF), response);
        expect_read(6'h00, pattern[0]);
        spi_write(6'h10, 32'hFFFF_FFFF);
        expect_read(6'h10, 32'd0);
        expect_read(6'h00, pattern[0]);

        // --------------------------------------------------------------------
        // TESTE 08 - 80 bits no mesmo CS: somente o primeiro frame e aceito
        // --------------------------------------------------------------------
        $display("\n[TESTE 08] Contador saturado em 40 bits");
        select_spi();
        transfer_bits(make_frame(1'b0, 6'h00, 1'b0, 32'hCAFE_BABE), 40, response);
        transfer_bits(make_frame(1'b0, 6'h00, 1'b0, 32'hDEAD_BEEF), 40, response);
        deselect_spi();
        expect_read(6'h00, 32'hCAFE_BABE);

        // --------------------------------------------------------------------
        // TESTE 09 - NOP interrompido / malformado / resposta consumida
        // --------------------------------------------------------------------
        $display("\n[TESTE 09] Retentativa de NOP e cabecalhos invalidos");
        read_request(6'h00);
        select_spi();
        transfer_bits(NOP_FRAME, 20, response);
        deselect_spi();
        spi_transaction(make_frame(1'b0, 6'h3F, 1'b0, 32'd0), response);
        check40("NOP de escrita nao transmite resposta", response, 40'd0);
        spi_transaction(make_frame(1'b1, 6'h3F, 1'b1, 32'd0), response);
        check40("NOP com RSV=1 nao transmite resposta", response, 40'd0);
        expect_nop(32'hCAFE_BABE,
                   "NOP repetido apos interrupcao e NOPs invalidos");
        expect_nop(32'd0, "Resposta invalidada apos NOP completo");

        // --------------------------------------------------------------------
        // TESTE 10 - Reset com resposta pendente e retorno a operacao normal
        // --------------------------------------------------------------------
        $display("\n[TESTE 10] Reset com leitura pendente e recuperacao");
        read_request(6'h00);
        reset_dut();
        expect_nop(32'd0, "Reset descarta resposta pendente");
        expect_read(6'h00, 32'd0);
        spi_write(6'h01, 32'hA1B2_C3D5);
        expect_read(6'h01, 32'hA1B2_C3D5);

        // --------------------------------------------------------------------
        // Relatorio consolidado
        // --------------------------------------------------------------------
        $display("\n============================================================");
        $display(" MiniSoC AES - Resultado do Testbench SPI");
        $display("============================================================");
        $display("Total de verificacoes : %0d", checks);
        $display("Total de falhas       : %0d", errors);
        if (errors != 0)
            $fatal(1, "FAIL: minisoc_spi_tb encontrou %0d falha(s)", errors);
        else
            $display("PASS: minisoc_spi_tb - todas as verificacoes passaram");
        $finish;
    end

    // Timeout global para evitar simulacao travada.
    initial begin
        #500000 $fatal(1, "FAIL: timeout global do minisoc_spi_tb");
    end

endmodule
