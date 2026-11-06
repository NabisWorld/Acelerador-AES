
`timescale 1ns/1ps

module minisoc_aes_inv_mix_columns_tb;

    logic [127:0] state_in;
    logic [127:0] state_out;
    logic [127:0] roundtrip_out;

    // Modulo inverso que queremos testar
    minisoc_aes_inv_mix_columns dut (
        .state_in(state_in),
        .state_out(state_out)
    );

    // Modulo original para verificar a inversao
    minisoc_aes_mix_columns u_forward (
        .state_in(state_out),
        .state_out(roundtrip_out)
    );

    task automatic check(
        input [127:0] entrada,
        input [127:0] esperado,
        input integer numero
    );
        begin
            state_in = entrada;
            #1;

            if (state_out !== esperado)
                $fatal(1, "FAIL: InvMixColumns teste %0d | Esperado: %h | Obtido: %h",
                       numero, esperado, state_out);

            if (roundtrip_out !== state_in)
                $fatal(1, "FAIL: Inversao teste %0d", numero);

            $display("PASS: InvMixColumns teste %0d", numero);
        end
    endtask

    initial begin

        // TESTE 1 - Exemplo intermediario da FIPS-197
        check(
            128'h046681E5E0CB199A48F8D37A2806264C,
            128'hD4BF5D30E0B452AEB84111F11E2798E5,
            1
        );

        // TESTE 2 - Exemplo AES-128
        check(
            128'h5F72641557F5BC92F7BE3B291DB9F91A,
            128'h6353E08C0960E104CD70B751BACAD0E7,
            2
        );

        // TESTE 3 - Entrada composta apenas por zeros
        check(
            128'h00000000000000000000000000000000,
            128'h00000000000000000000000000000000,
            3
        );

        // TESTE 4 - Colunas com quatro bytes iguais
        check(
            128'h57575757575757575757575757575757,
            128'h57575757575757575757575757575757,
            4
        );

        // TESTE 5 - Multiplicacao com reducao em GF(2^8)
        check(
            128'h1B80809B000000000000000000000000,
            128'h80000000000000000000000000000000,
            5
        );

        // TESTE 6 - Recuperacao de um estado adicional
        state_in = 128'h00112233445566778899AABBCCDDEEFF;
        #1;

        if (roundtrip_out !== state_in)
            $fatal(1, "FAIL: InvMixColumns roundtrip adicional");

        $display("PASS: InvMixColumns roundtrip adicional!");
        $display("PASS: Todos os testes do InvMixColumns!");

        $finish;

    end

endmodule
