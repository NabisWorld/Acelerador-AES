
`timescale 1ns/1ps

module minisoc_aes_inv_sub_bytes_tb;

    logic [127:0] state_in;
    logic [127:0] state_out;
    logic [127:0] roundtrip_out;

    integer valor, j;

    // Modulo inverso que queremos testar
    minisoc_aes_inv_sub_bytes dut (
        .state_in(state_in),
        .state_out(state_out)
    );

    // Modulo direto utilizado para conferir a inversao
    minisoc_aes_sub_bytes u_forward (
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
                $fatal(1, "FAIL: InvSubBytes teste %0d | Esperado: %h | Obtido: %h",
                       numero, esperado, state_out);

            if (roundtrip_out !== state_in)
                $fatal(1, "FAIL: Inversao teste %0d", numero);

            $display("PASS: InvSubBytes teste %0d", numero);
        end
    endtask

    initial begin

        // TESTE 1 - Vetor intermediario FIPS-197
        check(
            128'hD42711AEE0BF98F1B8B45DE51E415230,
            128'h193DE3BEA0F4E22B9AC68D2AE9F84808,
            1
        );

        // TESTE 2 - Rodada 10 da FIPS-197
        check(
            128'hE9098972CB31075F3D327D94AF2E2CB5,
            128'hEB40F21E592E38848BA113E71BC342D2,
            2
        );

        // TESTE 3 - Substituicao de 16 bytes conhecidos
        check(
            128'h638293C31BFC33F5C4EEACEA4BC12816,
            128'h00112233445566778899AABBCCDDEEFF,
            3
        );

        // TESTE 4 - Todos os 256 valores possiveis de byte
        for (valor = 0; valor < 256; valor = valor + 1) begin

            for (j = 0; j < 16; j = j + 1)
                state_in[127 - 8*j -: 8] = valor[7:0];

            #1;

            if (roundtrip_out !== state_in)
                $fatal(1, "FAIL: Inversao do byte %02h",
                       valor[7:0]);

        end

        $display("PASS: InvSubBytes - 256 valores verificados!");
        $display("PASS: Todos os testes do InvSubBytes!");

        $finish;

    end

endmodule
