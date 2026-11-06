
`timescale 1ns/1ps

module minisoc_aes_mix_columns_tb;

    logic [127:0] state_in;
    logic [127:0] state_out;

    minisoc_aes_mix_columns dut (
        .state_in(state_in),
        .state_out(state_out)
    );

    // Aplica um vetor, aguarda a logica combinacional e compara a saida.
    task automatic check_mix (
        input [127:0] entrada,
        input [127:0] esperado,
        input integer numero
    );
        begin
            state_in = entrada;
            #1;
            if (state_out !== esperado)
                $fatal(1, "FAIL: Teste %0d | Esperado: %h | Obtido: %h",
                       numero, esperado, state_out);
            else
                $display("PASS: Teste %0d", numero);
        end
    endtask

    initial begin
        // TESTE 1 - Rodada 1 do Apendice B da FIPS-197.
        // Entrada = saida do ShiftRows ja testado na Semana 2.
        check_mix(
            128'hD4BF5D30E0B452AEB84111F11E2798E5,
            128'h046681E5E0CB199A48F8D37A2806264C,
            1
        );

        // TESTE 2 - Rodada 1 do exemplo AES-128 da FIPS-197 (C.1 original).
        check_mix(
            128'h6353E08C0960E104CD70B751BACAD0E7,
            128'h5F72641557F5BC92F7BE3B291DB9F91A,
            2
        );

        // TESTE 3 - Estado composto apenas por zeros.
        check_mix(
            128'h00000000000000000000000000000000,
            128'h00000000000000000000000000000000,
            3
        );

        // TESTE 4 - Quatro bytes iguais em todas as colunas.
        check_mix(
            128'h57575757575757575757575757575757,
            128'h57575757575757575757575757575757,
            4
        );

        // TESTE 5 - Reducao em GF(2^8) (bit mais significativo em 1).
        check_mix(
            128'h80000000000000000000000000000000,
            128'h1B80809B000000000000000000000000,
            5
        );

        $display("PASS: Todos os testes do MixColumns!");
        $finish;
    end

endmodule
