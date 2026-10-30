
`timescale 1ns/1ps

module minisoc_aes_sub_bytes_tb;

    // Sinais de entrada e saída do SubBytes
    logic [127:0] state_in;
    logic [127:0] state_out;

    // Valor esperado após as 16 substituições
    logic [127:0] esperado;

    // Instância do módulo que queremos testar
    minisoc_aes_sub_bytes dut (
        .state_in(state_in),
        .state_out(state_out)
    );

    // Início do teste
    initial begin

        // Estado de entrada com 16 bytes conhecidos
        state_in = 128'h00112233445566778899AABBCCDDEEFF;

        // Resultado calculado a partir da S-box da FIPS-197
        esperado = 128'h638293C31BFC33F5C4EEACEA4BC12816;

        #1;

        // Comparação automática do estado completo
        if (state_out !== esperado)
            $fatal(1, "FAIL: Esperado: %h | Obtido: %h",
                   esperado, state_out);
        else
            $display("PASS: SubBytes produziu os 16 bytes esperados!");

    // =========================================
    // TESTE 2 - SubBytes da rodada 1 (FIPS-197)
    // =========================================

    state_in = 128'h193DE3BEA0F4E22B9AC68D2AE9F84808;
    esperado = 128'hD42711AEE0BF98F1B8B45DE51E415230;

    #1;

    if (state_out !== esperado)
        $fatal(1, "FAIL: Rodada 1 | Esperado: %h | Obtido: %h",
               esperado, state_out);
    else
        $display("PASS: SubBytes da rodada 1!");


    // =========================================
    // TESTE 3 - SubBytes da rodada 10 (FIPS-197)
    // =========================================

    state_in = 128'hEB40F21E592E38848BA113E71BC342D2;
    esperado = 128'hE9098972CB31075F3D327D94AF2E2CB5;

    #1;

    if (state_out !== esperado)
        $fatal(1, "FAIL: Rodada 10 | Esperado: %h | Obtido: %h",
               esperado, state_out);
    else
        $display("PASS: SubBytes da rodada 10!");



        $finish;

    end

endmodule
