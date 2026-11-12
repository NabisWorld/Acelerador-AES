`timescale 1ns/1ps

// MiniSoC AES-128 - Testbench integrado do datapath e da expansao de chave.
// Testa encrypt/decrypt usando os vetores FIPS-197 (Apendices C.1 e B).
module minisoc_aes_dp_tb;

    localparam logic [127:0] KEY_C1 = 128'h000102030405060708090A0B0C0D0E0F;
    localparam logic [127:0] PT_C1  = 128'h00112233445566778899AABBCCDDEEFF;
    localparam logic [127:0] CT_C1  = 128'h69C4E0D86A7B0430D8CDB78070B4C55A;

    localparam logic [127:0] KEY_B  = 128'h2B7E151628AED2A6ABF7158809CF4F3C;
    localparam logic [127:0] PT_B   = 128'h3243F6A8885A308D313198A2E0370734;
    localparam logic [127:0] CT_B   = 128'h3925841D02DC09FBDC118597196A0B32;

    logic         clk_i;
    logic         rst_n_i;

    // Interface da expansao de chave.
    logic         key_start_i;
    logic [127:0] key_i;
    logic [3:0]   round_sel;
    logic [127:0] round_key;
    logic         key_busy;
    logic         key_done;
    logic         keys_valid;

    // Interface do datapath.
    logic         dp_start_i;
    logic         decrypt_i;
    logic [127:0] block_i;
    logic [127:0] block_o;
    logic         dp_busy;
    logic         dp_done;

    minisoc_aes_key_exp u_key_exp (
        .clk_i        (clk_i),
        .rst_n_i      (rst_n_i),
        .start_i      (key_start_i),
        .key_i        (key_i),
        .round_sel_i  (round_sel),
        .round_key_o  (round_key),
        .busy_o       (key_busy),
        .done_o       (key_done),
        .keys_valid_o (keys_valid)
    );

    minisoc_aes_dp u_dp (
        .clk_i        (clk_i),
        .rst_n_i      (rst_n_i),
        .start_i      (dp_start_i),
        .decrypt_i    (decrypt_i),
        .block_i      (block_i),
        .keys_valid_i (keys_valid),
        .round_key_i  (round_key),
        .round_sel_o  (round_sel),
        .block_o      (block_o),
        .busy_o       (dp_busy),
        .done_o       (dp_done)
    );

    // Clock de periodo 10 ns.
    initial clk_i = 1'b0;
    always #5 clk_i = ~clk_i;

    // Carrega a chave original e espera a geracao completa de K0 a K10.
    task automatic load_key(input logic [127:0] new_key);
        begin
            @(negedge clk_i);
            key_i       = new_key;
            key_start_i = 1'b1;

            @(negedge clk_i);
            key_start_i = 1'b0;
            if (key_busy !== 1'b1 || keys_valid !== 1'b0 || key_done !== 1'b0)
                $fatal(1, "FAIL: Key Expansion nao iniciou corretamente");

            // Dez ciclos: gera K1, K2, ..., K10.
            for (int cycle = 1; cycle <= 10; cycle++) begin
                @(negedge clk_i);
                if (cycle < 10) begin
                    if (key_busy !== 1'b1 || keys_valid !== 1'b0 || key_done !== 1'b0)
                        $fatal(1, "FAIL: status da chave no ciclo %0d", cycle);
                end else begin
                    if (key_busy !== 1'b0 || keys_valid !== 1'b1 || key_done !== 1'b1)
                        $fatal(1, "FAIL: expansao de chave nao terminou no ciclo 10");
                end
            end

            @(negedge clk_i);
            if (key_done !== 1'b0 || keys_valid !== 1'b1)
                $fatal(1, "FAIL: done da chave nao foi um pulso / chaves invalidas");

            $display("PASS: Key Expansion concluido para chave %h", new_key);
        end
    endtask

    // Processa um bloco e verifica o resultado e a sequencia de round keys.
    task automatic run_block(
        input bit           do_decrypt,
        input logic [127:0] input_block,
        input logic [127:0] expected_block,
        input string        test_name
    );
        logic [3:0] expected_sel;
        begin
            if (keys_valid !== 1'b1)
                $fatal(1, "FAIL: tentativa de operar sem chaves validas");

            @(negedge clk_i);
            block_i    = input_block;
            decrypt_i  = do_decrypt;
            dp_start_i = 1'b1;

            // A primeira borda de subida captura o bloco, no estado IDLE.
            @(negedge clk_i);
            dp_start_i = 1'b0;
            if (dp_busy !== 1'b1 || dp_done !== 1'b0)
                $fatal(1, "FAIL: datapath nao iniciou (%s)", test_name);
            expected_sel = do_decrypt ? 4'd10 : 4'd0;
            if (round_sel !== expected_sel)
                $fatal(1, "FAIL: chave inicial incorreta (%s)", test_name);

            // Apos o inicio: INIT, nove ROUNDs, FINAL_ROUND e DONE.
            // No RTL proposto, done sobe 12 ciclos apos a captura do start.
            for (int cycle = 1; cycle <= 12; cycle++) begin
                @(negedge clk_i);

                if (cycle < 12) begin
                    if (dp_busy !== 1'b1 || dp_done !== 1'b0)
                        $fatal(1, "FAIL: status do datapath no ciclo %0d (%s)", cycle, test_name);
                end else begin
                    if (dp_busy !== 1'b0 || dp_done !== 1'b1)
                        $fatal(1, "FAIL: datapath nao concluiu no ciclo 12 (%s)", test_name);
                end

                // Confere K1..K9 na cifragem e K9..K1 na decriptação.
                if (cycle >= 1 && cycle <= 9) begin
                    expected_sel = do_decrypt ? (10 - cycle) : cycle;
                    if (round_sel !== expected_sel)
                        $fatal(1, "FAIL: chave selecionada no ciclo %0d (%s)", cycle, test_name);
                end

                // A rodada final usa K10 (encrypt) ou K0 (decrypt).
                if (cycle == 10) begin
                    expected_sel = do_decrypt ? 4'd0 : 4'd10;
                    if (round_sel !== expected_sel)
                        $fatal(1, "FAIL: chave da rodada final (%s)", test_name);
                end

                // Um segundo start durante a rodada nao pode reiniciar o bloco.
                if (cycle == 3) begin
                    dp_start_i = 1'b1;
                    block_i    = '1;
                    decrypt_i  = ~do_decrypt;
                end else if (cycle == 4) begin
                    dp_start_i = 1'b0;
                    block_i    = input_block;
                    decrypt_i  = do_decrypt;
                end
            end

            if (block_o !== expected_block)
                $fatal(1, "FAIL: %s | esperado=%h obtido=%h", test_name, expected_block, block_o);

            // O pulso done deve terminar; o resultado deve continuar disponivel.
            @(negedge clk_i);
            if (dp_done !== 1'b0 || dp_busy !== 1'b0 || block_o !== expected_block)
                $fatal(1, "FAIL: done ou retencao do resultado (%s)", test_name);

            $display("PASS: %s | resultado=%h", test_name, block_o);
        end
    endtask

    initial begin
        rst_n_i     = 1'b0;
        key_start_i = 1'b0;
        key_i       = '0;
        dp_start_i  = 1'b0;
        decrypt_i   = 1'b0;
        block_i     = '0;

        repeat (2) @(negedge clk_i);
        rst_n_i = 1'b1;

        // Sem keys_valid, o start do datapath nao deve ser aceito.
        @(negedge clk_i);
        block_i     = PT_C1;
        dp_start_i  = 1'b1;
        @(negedge clk_i);
        dp_start_i  = 1'b0;
        if (dp_busy !== 1'b0 || dp_done !== 1'b0)
            $fatal(1, "FAIL: datapath aceitou start sem round keys");
        $display("PASS: start ignorado quando keys_valid=0");

        $display("==> Vetor FIPS-197 C.1");
        load_key(KEY_C1);
        run_block(1'b0, PT_C1, CT_C1, "C.1 encrypt");
        run_block(1'b1, CT_C1, PT_C1, "C.1 decrypt");

        $display("==> Vetor FIPS-197 B");
        load_key(KEY_B);
        run_block(1'b0, PT_B, CT_B, "B encrypt");
        run_block(1'b1, CT_B, PT_B, "B decrypt");

        // Reset no meio da operacao deve interromper o datapath
        // e invalidar as chaves armazenadas.
        @(negedge clk_i);
        dp_start_i = 1'b1;
        block_i = PT_B;
        decrypt_i = 1'b0;
        @(negedge clk_i);
        dp_start_i = 1'b0;
        if (dp_busy !== 1'b1)
            $fatal(1, "FAIL: teste de reset nao iniciou");
        repeat (3) @(negedge clk_i);
        rst_n_i = 1'b0;
        @(negedge clk_i);
        if (dp_busy !== 1'b0 || dp_done !== 1'b0 || keys_valid !== 1'b0 ||
            block_o !== 128'h0)
            $fatal(1, "FAIL: reset nao interrompeu o datapath");
        $display("PASS: reset interrompeu a operacao");

        $display("PASS: Datapath AES-128 - todos os testes!");
        $finish;
    end

    // Protecao contra travamento da simulacao.
    initial begin
        #20000;
        $fatal(1, "FAIL: timeout da simulacao");
    end

endmodule
