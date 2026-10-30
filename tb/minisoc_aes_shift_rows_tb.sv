
`timescale 1ns/1ps

module minisoc_aes_shift_rows_tb;

    // Sinais de entrada e saída do ShiftRows
    logic [127:0] state_in;
    logic [127:0] state_out;

    // Estado esperado após os deslocamentos
    logic [127:0] esperado;

    // Instância do módulo que será testado
    minisoc_aes_shift_rows dut (
        .state_in(state_in),
        .state_out(state_out)
    );

    initial begin

        // TESTE 1 - Estado com bytes de 00 até 0F
        state_in = 128'h000102030405060708090A0B0C0D0E0F;

        // Resultado esperado após ShiftRows
        esperado = 128'h00050A0F04090E03080D02070C01060B;

        #1;

        // Comparação automática dos 128 bits
        if (state_out !== esperado)
            $fatal(1, "FAIL: Esperado: %h | Obtido: %h",
                   esperado, state_out);
        else
            $display("PASS: ShiftRows reorganizou os 16 bytes corretamente!");

    
        // =========================================
        // TESTE 2 - ShiftRows da rodada 1 (FIPS-197)
        // =========================================

        state_in = 128'hD42711AEE0BF98F1B8B45DE51E415230;
        esperado = 128'hD4BF5D30E0B452AEB84111F11E2798E5;

        #1;

        if (state_out !== esperado)
            $fatal(1, "FAIL: Rodada 1 | Esperado: %h | Obtido: %h",
                esperado, state_out);
        else
            $display("PASS: ShiftRows da rodada 1!");


        // =========================================
        // TESTE 3 - ShiftRows da rodada 10 (FIPS-197)
        // =========================================

        state_in = 128'hE9098972CB31075F3D327D94AF2E2CB5;
        esperado = 128'hE9317DB5CB322C723D2E895FAF090794;

        #1;

        if (state_out !== esperado)
            $fatal(1, "FAIL: Rodada 10 | Esperado: %h | Obtido: %h",
                esperado, state_out);
        else
            $display("PASS: ShiftRows da rodada 10!");

        $finish;

    end

endmodule



