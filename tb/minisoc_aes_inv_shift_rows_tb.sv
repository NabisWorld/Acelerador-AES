
`timescale 1ns/1ps

module minisoc_aes_inv_shift_rows_tb;

    logic [127:0] state_in;
    logic [127:0] state_out;
    logic [127:0] roundtrip_out;

    // Modulo inverso que queremos testar
    minisoc_aes_inv_shift_rows dut (
        .state_in(state_in),
        .state_out(state_out)
    );

    // Modulo original para verificar a inversao
    minisoc_aes_shift_rows u_forward (
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
                $fatal(1, "FAIL: InvShiftRows teste %0d", numero);

            if (roundtrip_out !== state_in)
                $fatal(1, "FAIL: Inversao teste %0d", numero);

            $display("PASS: InvShiftRows teste %0d", numero);
        end
    endtask

    initial begin

        // TESTE 1 - Sequencia de bytes
        check(
            128'h00050A0F04090E03080D02070C01060B,
            128'h000102030405060708090A0B0C0D0E0F,
            1
        );

        // TESTE 2 - Rodada 1 da FIPS-197
        check(
            128'hD4BF5D30E0B452AEB84111F11E2798E5,
            128'hD42711AEE0BF98F1B8B45DE51E415230,
            2
        );

        // TESTE 3 - Rodada 10 da FIPS-197
        check(
            128'hE9317DB5CB322C723D2E895FAF090794,
            128'hE9098972CB31075F3D327D94AF2E2CB5,
            3
        );

        $display("PASS: Todos os testes do InvShiftRows!");
        $finish;

    end

endmodule
