module minisoc_aes_inv_mix_columns (
    input  logic [127:0] state_in,
    output logic [127:0] state_out
);

    // Multiplicacao por 02 em GF(2^8) com reducao pelo polinomio AES.
    function automatic [7:0] xtime(input [7:0] a);
        begin
            xtime = {a[6:0], 1'b0} ^ (a[7] ? 8'h1B : 8'h00);
        end
    endfunction

    // Multiplicacao pelos coeficientes 09, 0B, 0D e 0E.
    function automatic [7:0] mul_inv(
        input [7:0] a,
        input [3:0] coef
    );
        reg [7:0] a2, a4, a8;
        begin
            a2 = xtime(a);
            a4 = xtime(a2);
            a8 = xtime(a4);

            case (coef)
                4'h9: mul_inv = a8 ^ a;
                4'hB: mul_inv = a8 ^ a2 ^ a;
                4'hD: mul_inv = a8 ^ a4 ^ a;
                4'hE: mul_inv = a8 ^ a4 ^ a2;
                default: mul_inv = 8'h00;
            endcase
        end
    endfunction

    // Transforma uma coluna de quatro bytes.
    function automatic [31:0] inv_mix_column(
        input [31:0] column_in
    );
        reg [7:0] a0, a1, a2, a3;
        reg [7:0] b0, b1, b2, b3;
        begin
            {a0, a1, a2, a3} = column_in;

            // Multiplicacao pela matriz inversa do AES.
            b0 = mul_inv(a0, 4'hE) ^ mul_inv(a1, 4'hB) ^
                 mul_inv(a2, 4'hD) ^ mul_inv(a3, 4'h9);

            b1 = mul_inv(a0, 4'h9) ^ mul_inv(a1, 4'hE) ^
                 mul_inv(a2, 4'hB) ^ mul_inv(a3, 4'hD);

            b2 = mul_inv(a0, 4'hD) ^ mul_inv(a1, 4'h9) ^
                 mul_inv(a2, 4'hE) ^ mul_inv(a3, 4'hB);

            b3 = mul_inv(a0, 4'hB) ^ mul_inv(a1, 4'hD) ^
                 mul_inv(a2, 4'h9) ^ mul_inv(a3, 4'hE);

            inv_mix_column = {b0, b1, b2, b3};
        end
    endfunction

    // Quatro colunas calculadas em paralelo.
    assign state_out[127:96] = inv_mix_column(state_in[127:96]);
    assign state_out[95:64]  = inv_mix_column(state_in[95:64]);
    assign state_out[63:32]  = inv_mix_column(state_in[63:32]);
    assign state_out[31:0]   = inv_mix_column(state_in[31:0]);

endmodule
