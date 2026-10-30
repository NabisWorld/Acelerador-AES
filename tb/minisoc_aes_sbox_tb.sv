
`timescale 1ns/1ps

module minisoc_aes_sbox_tb;

    // Sinais utilizados pelo testbench
    logic [7:0] byte_in;
    logic [7:0] byte_out;
    logic [7:0] esperado [0:255];

    // Instância do módulo S-box que queremos testar
    minisoc_aes_sbox dut (
        .byte_in(byte_in),
        .byte_out(byte_out)
    );

    // Início dos testes
initial begin

    // Carrega os 256 valores de referência da FIPS-197
    $readmemh("tb/vectors/aes_sbox_ref.hex", esperado);

    // Percorre todas as entradas possíveis da S-box
    for (int i = 0; i < 256; i++) begin

        // Envia o valor atual para a S-box
        byte_in = i[7:0];
        #1;

        // Compara a saída com o valor esperado
        if (byte_out !== esperado[i])
            $fatal(1, "FAIL: Entrada %h | Esperado: %h | Obtido: %h",
                   byte_in, esperado[i], byte_out);

    end

    // Só chega aqui se todas as comparações passarem
    $display("PASS: Todas as 256 entradas da S-box foram verificadas!");

    $finish;

end

endmodule

