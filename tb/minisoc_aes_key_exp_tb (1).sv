`timescale 1ns/1ps

// Testbench autoverificavel para a expansao de chave AES-128.
module minisoc_aes_key_exp_tb;

    logic clk_i;
    logic rst_n_i;
    logic start_i;
    logic [127:0] key_i;
    logic [3:0] round_sel_i;
    logic [127:0] round_key_o;
    logic busy_o;
    logic done_o;
    logic keys_valid_o;

    logic [127:0] expected_a [0:10];
    logic [127:0] expected_b [0:10];

    minisoc_aes_key_exp dut (
        .clk_i(clk_i),
        .rst_n_i(rst_n_i),
        .start_i(start_i),
        .key_i(key_i),
        .round_sel_i(round_sel_i),
        .round_key_o(round_key_o),
        .busy_o(busy_o),
        .done_o(done_o),
        .keys_valid_o(keys_valid_o)
    );

    initial clk_i = 1'b0;
    always #5 clk_i = ~clk_i; // Periodo de 10 ns.

    // Aceita uma nova chave, aguarda exatamente 10 ciclos de geracao e
    // confere as 11 round keys nos dois sentidos.
    task automatic test_key(input logic [127:0] test_key_i,
                            input bit use_key_b);
        logic [127:0] expected;
        begin
            @(negedge clk_i);
            key_i = test_key_i;
            start_i = 1'b1;

            // Borda que captura K0 e inicia a expansao.
            @(negedge clk_i);
            start_i = 1'b0;
            if (busy_o !== 1'b1 || keys_valid_o !== 1'b0 || done_o !== 1'b0)
                $fatal(1, "FAIL: expansao nao iniciou corretamente");

            round_sel_i = 4'd0;
            if (round_key_o !== 128'h0)
                $fatal(1, "FAIL: round key foi exposta antes da conclusao");

            for (int cycle = 1; cycle <= 10; cycle++) begin
                @(negedge clk_i);

                if (cycle < 10) begin
                    if (busy_o !== 1'b1 || keys_valid_o !== 1'b0 || done_o !== 1'b0)
                        $fatal(1, "FAIL: status incorreto durante ciclo %0d", cycle);
                end else begin
                    if (busy_o !== 1'b0 || keys_valid_o !== 1'b1 || done_o !== 1'b1)
                        $fatal(1, "FAIL: conclusao incorreta apos 10 ciclos");
                end

                // Uma segunda solicitacao durante busy deve ser ignorada.
                if (cycle == 3) begin
                    start_i = 1'b1;
                    key_i = 128'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;
                end else if (cycle == 4) begin
                    start_i = 1'b0;
                    key_i = test_key_i;
                end
            end

            @(negedge clk_i);
            if (done_o !== 1'b0 || keys_valid_o !== 1'b1)
                $fatal(1, "FAIL: done nao foi pulso de um ciclo / keys_valid nao persistiu");

            // Ordem de cifragem: K0 -> K10.
            for (int r = 0; r <= 10; r++) begin
                round_sel_i = r[3:0];
                @(negedge clk_i);
                expected = use_key_b ? expected_b[r] : expected_a[r];
                if (round_key_o !== expected)
                    $fatal(1, "FAIL: K%0d esperada %h, obtida %h", r, expected, round_key_o);
            end
            $display("PASS: 11 round keys em ordem direta");

            // Ordem de decriptação: K10 -> K0 (sem recalculo).
            for (int r = 10; r >= 0; r--) begin
                round_sel_i = r[3:0];
                @(negedge clk_i);
                expected = use_key_b ? expected_b[r] : expected_a[r];
                if (round_key_o !== expected)
                    $fatal(1, "FAIL: leitura inversa K%0d", r);
            end
            $display("PASS: 11 round keys em ordem inversa");

            round_sel_i = 4'd11;
            @(negedge clk_i);
            if (round_key_o !== 128'h0)
                $fatal(1, "FAIL: indice 11 deveria retornar zero");
            $display("PASS: indice de rodada invalido protegido");
        end
    endtask

    initial begin
        // Exemplo C.1: chave 00 01 ... 0F.
        expected_a[0]  = 128'h000102030405060708090A0B0C0D0E0F;
        expected_a[1]  = 128'hD6AA74FDD2AF72FADAA678F1D6AB76FE;
        expected_a[2]  = 128'hB692CF0B643DBDF1BE9BC5006830B3FE;
        expected_a[3]  = 128'hB6FF744ED2C2C9BF6C590CBF0469BF41;
        expected_a[4]  = 128'h47F7F7BC95353E03F96C32BCFD058DFD;
        expected_a[5]  = 128'h3CAAA3E8A99F9DEB50F3AF57ADF622AA;
        expected_a[6]  = 128'h5E390F7DF7A69296A7553DC10AA31F6B;
        expected_a[7]  = 128'h14F9701AE35FE28C440ADF4D4EA9C026;
        expected_a[8]  = 128'h47438735A41C65B9E016BAF4AEBF7AD2;
        expected_a[9]  = 128'h549932D1F08557681093ED9CBE2C974E;
        expected_a[10] = 128'h13111D7FE3944A17F307A78B4D2B30C5;

        // Exemplo B/A.1: chave 2B 7E ... 3C.
        expected_b[0]  = 128'h2B7E151628AED2A6ABF7158809CF4F3C;
        expected_b[1]  = 128'hA0FAFE1788542CB123A339392A6C7605;
        expected_b[2]  = 128'hF2C295F27A96B9435935807A7359F67F;
        expected_b[3]  = 128'h3D80477D4716FE3E1E237E446D7A883B;
        expected_b[4]  = 128'hEF44A541A8525B7FB671253BDB0BAD00;
        expected_b[5]  = 128'hD4D1C6F87C839D87CAF2B8BC11F915BC;
        expected_b[6]  = 128'h6D88A37A110B3EFDDBF98641CA0093FD;
        expected_b[7]  = 128'h4E54F70E5F5FC9F384A64FB24EA6DC4F;
        expected_b[8]  = 128'hEAD27321B58DBAD2312BF5607F8D292F;
        expected_b[9]  = 128'hAC7766F319FADC2128D12941575C006E;
        expected_b[10] = 128'hD014F9A8C9EE2589E13F0CC8B6630CA6;

        rst_n_i = 1'b0;
        start_i = 1'b0;
        key_i = '0;
        round_sel_i = 4'd0;

        repeat (2) @(negedge clk_i);
        rst_n_i = 1'b1;

        $display("==> Teste 1: chave do Ap. C.1");
        test_key(expected_a[0], 1'b0);

        $display("==> Teste 2: chave do Ap. B/A.1 (nova operacao)");
        test_key(expected_b[0], 1'b1);

        // Verifica reset no meio de uma nova expansao.
        @(negedge clk_i);
        start_i = 1'b1;
        key_i = expected_a[0];
        @(negedge clk_i);
        start_i = 1'b0;
        repeat (3) @(negedge clk_i);
        rst_n_i = 1'b0;
        @(negedge clk_i);
        round_sel_i = 4'd0;
        if (busy_o !== 1'b0 || done_o !== 1'b0 || keys_valid_o !== 1'b0 ||
            round_key_o !== 128'h0)
            $fatal(1, "FAIL: reset nao limpou controle e validade");
        $display("PASS: reset interrompeu expansao e invalidou chaves");

        $display("PASS: Key Expansion AES-128 - todos os testes!");
        $finish;
    end

    initial begin
        #10000 $fatal(1, "FAIL: timeout da simulacao");
    end

endmodule
