module minisoc_aes_mix_columns (
    input  logic [127:0] state_in,
    output logic [127:0] state_out
);

    // Multiplicacao por 02 em GF(2^8), usando o polinomio do AES.
    function automatic [7:0] xtime(input [7:0] a);
        begin
            xtime = {a[6:0], 1'b0} ^ (a[7] ? 8'h1B : 8'h00);
        end
    endfunction

    // Aplica MixColumns a uma coluna de quatro bytes (32 bits).
    function automatic [31:0] mix_column(input [31:0] column_in);
        reg [7:0] a0, a1, a2, a3;
        reg [7:0] x0, x1, x2, x3;
        reg [7:0] b0, b1, b2, b3;
        begin
            {a0, a1, a2, a3} = column_in;

            // xN = 02 * aN; 03 * aN = xN XOR aN.
            x0 = xtime(a0);
            x1 = xtime(a1);
            x2 = xtime(a2);
            x3 = xtime(a3);

            // Multiplicacao pela matriz fixa do MixColumns.
            b0 = x0 ^ (x1 ^ a1) ^ a2 ^ a3;
            b1 = a0 ^ x1 ^ (x2 ^ a2) ^ a3;
            b2 = a0 ^ a1 ^ x2 ^ (x3 ^ a3);
            b3 = (x0 ^ a0) ^ a1 ^ a2 ^ x3;

            mix_column = {b0, b1, b2, b3};
        end
    endfunction

    // Quatro colunas independentes, calculadas em paralelo.
    assign state_out[127:96] = mix_column(state_in[127:96]);
    assign state_out[95:64]  = mix_column(state_in[95:64]);
    assign state_out[63:32]  = mix_column(state_in[63:32]);
    assign state_out[31:0]   = mix_column(state_in[31:0]);

endmodule
