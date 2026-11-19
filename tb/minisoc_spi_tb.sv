`timescale 1ns/1ps

// Testbench dirigido e autoverificavel do SPI Front-End - Semana 5.
// Hipotese de protocolo: NOP READ (8'hFE), MISO = {8'h00, DATA[31:0]}.
// O PLL e o AES ainda nao estao integrados: seus status sao estimulados aqui.
module minisoc_spi_tb;
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
    logic aes_busy_i = 1'b0;
    logic aes_done_i = 1'b0;
    logic aes_error_i = 1'b0;
    logic [8:0] aes_blocks_done_i = 9'd0;
    logic mem_sel_aes_o, pll_enable_o;
    logic [1:0] pll_div_sel_o;
    logic pll_locked_i = 1'b0;

    localparam logic [31:0] EXPECTED_VERSION = 32'h0001_0000;
    localparam logic [39:0] NOP_FRAME = 40'hFE00000000;
    int checks = 0;
    int start_pulses = 0;
    logic prev_start = 1'b0;
    logic [31:0] pattern [0:10];
    logic [39:0] response;
    int pulses_before;

    minisoc_spi dut (.*);
    always #0.25 clk_i = ~clk_i; // 2 GHz, periodo 500 ps.

    // Monitora o START no meio do ciclo always-on (sem disputa com NBA).
    always @(negedge clk_i) begin
        if (!rst_n_i) begin
            prev_start = 1'b0;
            start_pulses = 0;
        end else begin
            if ((aes_start_o === 1'b1) && (prev_start === 1'b1))
                $fatal(1, "FAIL: START durou mais de um ciclo de clk_i");
            if (aes_start_o === 1'b1)
                start_pulses = start_pulses + 1;
            prev_start = aes_start_o;
        end
    end

    function automatic logic [39:0] make_frame(
        input logic rwb, input logic [5:0] addr,
        input logic rsv, input logic [31:0] data
    );
        return {rwb, addr, rsv, data};
    endfunction

    task automatic check(input logic condition, input string description);
        if (condition !== 1'b1)
            $fatal(1, "FAIL: %s", description);
        checks = checks + 1;
        $display("PASS: %s", description);
    endtask

    // SPI Mode 0, 25 MHz. MOSI antes da subida; MISO lido na subida.
    // Nao modifica CS: permite exercitar frames incompletos e excedentes.
    task automatic transfer_bits(
        input logic [39:0] frame,
        input int nbits,
        output logic [39:0] received
    );
        logic miso_at_edge;
        received = '0;
        for (int i = 39; i >= 40-nbits; i--) begin
            spi_mosi_i = frame[i];
            #20;
            miso_at_edge = spi_miso_o;
            spi_sclk_i = 1'b1;
            received = {received[38:0], miso_at_edge};
            #1;
            if (spi_miso_o !== miso_at_edge)
                $fatal(1, "FAIL: MISO mudou na borda de subida (bit %0d)", i);
            #19;
            spi_sclk_i = 1'b0;
        end
    endtask

    task automatic select_spi;
        spi_cs_n_i = 1'b0;
        #2.3; // CS setup; fase nao alinhada com clk_i.
    endtask

    task automatic deselect_spi;
        #1;
        spi_cs_n_i = 1'b1;
        spi_mosi_i = 1'b0;
        #2; // SCLK permanece parado entre transacoes.
        if (spi_miso_o !== 1'b0)
            $fatal(1, "FAIL: MISO deveria estar em zero fora da transacao");
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
        if (ignored !== 40'd0)
            $fatal(1, "FAIL: MISO nao nulo durante escrita em %h", addr);
    endtask

    task automatic read_request(input logic [5:0] addr);
        logic [39:0] ignored;
        spi_transaction(make_frame(1'b1, addr, 1'b0, 32'hA5A5A5A5), ignored);
        if (ignored !== 40'd0)
            $fatal(1, "FAIL: MISO nao nulo na solicitacao READ %h", addr);
    endtask

    task automatic expect_nop(input logic [31:0] expected, input string description);
        logic [39:0] received;
        spi_transaction(NOP_FRAME, received);
        if (received !== {8'h00, expected})
            $fatal(1, "FAIL: %s: esperado %h, recebido %h", description,
                   {8'h00, expected}, received);
        check(1'b1, description);
    endtask

    task automatic expect_read(input logic [5:0] addr, input logic [31:0] expected);
        read_request(addr);
        expect_nop(expected, $sformatf("READ 0x%02h = 0x%08h", addr, expected));
    endtask

    task automatic reset_dut;
        // Gera uma borda real de reset; nao depende de SCLK.
        spi_cs_n_i = 1'b1;
        spi_sclk_i = 1'b0;
        spi_mosi_i = 1'b0;
        rst_n_i = 1'b0;
        #4;
        rst_n_i = 1'b1;
        #3.1;
    endtask

    initial begin
        #500000;
        $fatal(1, "FAIL: timeout global");
    end

    initial begin
        #1;
        reset_dut();
        check({cfg_key_o, cfg_iv_o, cfg_counter_o, cfg_num_blocks_o,
               cfg_mode_o, cfg_decrypt_o, aes_start_o, mem_sel_aes_o,
               pll_enable_o, pll_div_sel_o} === '0, "Reset das configuracoes");
        expect_nop(32'd0, "NOP sem leitura apos reset");
        expect_read(6'h0D, EXPECTED_VERSION);
        expect_read(6'h0A, 32'd0);
        expect_read(6'h0E, 32'd0);

        // 0x00..0x0A: padroes distintos para verificar ordem e endereco.
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
        check(cfg_key_o === {pattern[0],pattern[1],pattern[2],pattern[3]}, "Ordem KEY0..KEY3 nas saidas");
        check(cfg_iv_o === {pattern[4],pattern[5],pattern[6],pattern[7]}, "Ordem IV0..IV3 nas saidas");
        check(cfg_counter_o === {pattern[8],pattern[9]}, "Ordem COUNTER_HI/LO nas saidas");
        check(cfg_num_blocks_o === 32'd256, "NUM_BLOCKS = 256 sem truncamento");
        spi_write(6'h0A, 32'h80000201);
        expect_read(6'h0A, 32'h80000201);
        check(cfg_num_blocks_o === 32'h80000201, "Preservacao integral de NUM_BLOCKS invalido (validacao futura no AES)");

        // AES_CONTROL: mascara de reservados, MODE, DECRYPT, START.
        pulses_before = start_pulses;
        spi_write(6'h0B, 32'hFFFFFFF6); // MODE 101, DECRYPT=1, START=0.
        expect_read(6'h0B, 32'h00000016);
        check(cfg_mode_o === 3'b101 && cfg_decrypt_o === 1'b1, "Campos MODE e DECRYPT");
        check(start_pulses == pulses_before, "Escrita de START=0 nao gera pulso");
        spi_write(6'h0B, 32'h00000017);
        check(start_pulses == pulses_before+1 && aes_start_o === 1'b0, "START=1 gera um unico pulso de clk_i");
        expect_read(6'h0B, 32'h00000016);
        check(start_pulses == pulses_before+1, "Leitura de AES_CONTROL nao gera START");
        spi_write(6'h0B, 32'h00000017);
        check(start_pulses == pulses_before+2, "Segunda escrita START=1 gera novo pulso");

        // SYSTEM_CONTROL: todas as selecoes de divisor, com enable e ownership.
        // Verifica interface SPI, nao frequencia nem aquisicao real do PLL.
        for (int d = 0; d < 4; d++) begin
            spi_write(6'h0E, 32'hFFFFFFF3 | (32'(d) << 2));
            expect_read(6'h0E, 32'h3 | (32'(d) << 2));
            check(pll_div_sel_o === 2'(d) && pll_enable_o === 1'b1 && mem_sel_aes_o === 1'b1,
                  $sformatf("Saidas SYSTEM_CONTROL divisor %0d", d));
        end
        spi_write(6'h0E, 32'd0);
        expect_read(6'h0E, 32'd0);
        check(pll_enable_o === 1'b0 && mem_sel_aes_o === 1'b0, "Desabilitacao PLL e ownership externo");

        // Status simulados: testa todos os bits e protecao contra escrita.
        aes_blocks_done_i = 9'd256;
        aes_error_i = 1'b1;
        aes_done_i = 1'b1;
        aes_busy_i = 1'b1;
        pll_locked_i = 1'b1;
        expect_read(6'h0C, 32'h00000807);
        expect_read(6'h0F, 32'd1);
        spi_write(6'h0C, 32'd0);
        spi_write(6'h0D, 32'hDEADBEEF);
        spi_write(6'h0F, 32'd0);
        expect_read(6'h0C, 32'h00000807);
        expect_read(6'h0D, EXPECTED_VERSION);
        expect_read(6'h0F, 32'd1);
        pll_locked_i = 1'b0;
        expect_read(6'h0F, 32'd0);
        aes_blocks_done_i = 9'd0;
        aes_error_i = 1'b0;
        aes_done_i = 1'b0;
        aes_busy_i = 1'b0;
        expect_read(6'h0C, 32'd0);

        // Snapshot dos status: o valor muda apos READ e durante o NOP.
        aes_blocks_done_i = 9'd17;
        aes_busy_i = 1'b1;
        read_request(6'h0C);
        aes_blocks_done_i = 9'd18;
        fork
            begin
                #600;
                aes_blocks_done_i = 9'd19;
                aes_done_i = 1'b1;
            end
            begin
                expect_nop(32'h00000089, "Snapshot de AES_STATUS estavel durante NOP");
            end
        join
        expect_nop(32'd0, "Segundo NOP nao repete resposta consumida");
        expect_read(6'h0C, 32'h0000009B);

        // Frames invalidos e interrupcoes - decisoes locais de projeto.
        select_spi();
        transfer_bits(make_frame(1'b0,6'h00,1'b0,32'hDEADBEEF), 39, response);
        deselect_spi();
        expect_read(6'h00, pattern[0]);
        spi_transaction(make_frame(1'b0,6'h00,1'b1,32'hDEADBEEF), response);
        expect_read(6'h00, pattern[0]);
        spi_write(6'h10, 32'hFFFFFFFF);
        expect_read(6'h10, 32'd0);
        expect_read(6'h00, pattern[0]);
        // 80 bits no mesmo CS: somente os primeiros 40 devem ser aceitos.
        select_spi();
        transfer_bits(make_frame(1'b0,6'h00,1'b0,32'hCAFEBABE), 40, response);
        transfer_bits(make_frame(1'b0,6'h00,1'b0,32'hDEADBEEF), 40, response);
        deselect_spi();
        expect_read(6'h00, 32'hCAFEBABE);

        // NOP interrompido preserva a resposta; NOP malformado nao consome.
        read_request(6'h00);
        select_spi();
        transfer_bits(NOP_FRAME, 20, response);
        deselect_spi();
        spi_transaction(make_frame(1'b0,6'h3F,1'b0,32'd0), response);
        check(response === 40'd0, "NOP de escrita nao transmite resposta");
        spi_transaction(make_frame(1'b1,6'h3F,1'b1,32'd0), response);
        check(response === 40'd0, "NOP com RSV=1 nao transmite resposta");
        expect_nop(32'hCAFEBABE, "NOP repetido apos interrupcao e NOPs invalidos");
        expect_nop(32'd0, "Resposta invalidada apos NOP completo");

        // Reset com uma resposta pendente, sem bordas extras de SPI.
        read_request(6'h00);
        reset_dut();
        expect_nop(32'd0, "Reset descarta resposta pendente");
        expect_read(6'h00, 32'd0);
        spi_write(6'h01, 32'hA1B2C3D5);
        expect_read(6'h01, 32'hA1B2C3D5);
        $display("PASS: minisoc_spi_tb - %0d verificacoes concluidas", checks);
        $finish;
    end
endmodule
