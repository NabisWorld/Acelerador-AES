
`timescale 1ns/1ps

module minisoc_aes_add_round_key_tb;

    // Sinais de entrada e saida do AddRoundKey
    logic [127:0] state_in;
    logic [127:0] round_key;
    logic [127:0] state_out;

    // Resultado esperado da operacao
    logic [127:0] esperado;

    // Instancia do modulo que sera testado
    minisoc_aes_add_round_key dut (
        .state_in(state_in),
        .round_key(round_key),
        .state_out(state_out)
    );

    initial begin

        // =========================================
        // TESTE 1 - AddRoundKey inicial (FIPS-197)
        // =========================================

        state_in  = 128'h00112233445566778899AABBCCDDEEFF;
        round_key = 128'h000102030405060708090A0B0C0D0E0F;
        esperado  = 128'h00102030405060708090A0B0C0D0E0F0;

        #1;

        if (state_out !== esperado)
            $fatal(1, "FAIL: Teste 1 | Esperado: %h | Obtido: %h",
                   esperado, state_out);
        else
            $display("PASS: AddRoundKey inicial!");


        // =========================================
        // TESTE 2 - AddRoundKey da rodada 1
        // =========================================

        state_in  = 128'h5F72641557F5BC92F7BE3B291DB9F91A;
        round_key = 128'hD6AA74FDD2AF72FADAA678F1D6AB76FE;
        esperado  = 128'h89D810E8855ACE682D1843D8CB128FE4;

        #1;

        if (state_out !== esperado)
            $fatal(1, "FAIL: Teste 2 | Esperado: %h | Obtido: %h",
                   esperado, state_out);
        else
            $display("PASS: AddRoundKey da rodada 1!");


        // =========================================
        // TESTE 3 - XOR com chave igual a zero
        // =========================================

        state_in  = 128'h00112233445566778899AABBCCDDEEFF;
        round_key = 128'h00000000000000000000000000000000;
        esperado  = state_in;

        #1;

        if (state_out !== esperado)
            $fatal(1, "FAIL: Teste 3 | Esperado: %h | Obtido: %h",
                   esperado, state_out);
        else
            $display("PASS: XOR com zero!");


        // =========================================
        // TESTE 4 - XOR entre valores iguais
        // =========================================

        state_in  = 128'h00112233445566778899AABBCCDDEEFF;
        round_key = state_in;
        esperado  = 128'h00000000000000000000000000000000;

        #1;

        if (state_out !== esperado)
            $fatal(1, "FAIL: Teste 4 | Esperado: %h | Obtido: %h",
                   esperado, state_out);
        else
            $display("PASS: XOR entre valores iguais!");

        $display("PASS: Todos os testes do AddRoundKey!");

        $finish;

    end

endmodule
