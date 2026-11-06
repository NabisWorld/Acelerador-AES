module minisoc_aes_inv_sub_bytes (
    input  logic [127:0] state_in,
    output logic [127:0] state_out
);

    // Aplica a S-box inversa aos 16 bytes do estado.
    // As instancias operam em paralelo.

    for (genvar i = 0; i < 16; i = i + 1) begin : gen_inv_sbox

        minisoc_aes_inv_sbox u_inv_sbox (
            .byte_in (state_in [127 - 8*i -: 8]),
            .byte_out(state_out[127 - 8*i -: 8])
        );

    end

endmodule
