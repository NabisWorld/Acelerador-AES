
module minisoc_aes_sub_bytes (
    input  logic [127:0] state_in,
    output logic [127:0] state_out
);

    // S-box 0 - Primeiro byte
    minisoc_aes_sbox sbox_0 (
        .byte_in(state_in[127:120]),
        .byte_out(state_out[127:120])
    );

    // S-box 1
    minisoc_aes_sbox sbox_1 (
        .byte_in(state_in[119:112]),
        .byte_out(state_out[119:112])
    );

    // S-box 2
    minisoc_aes_sbox sbox_2 (
        .byte_in(state_in[111:104]),
        .byte_out(state_out[111:104])
    );

    // S-box 3
    minisoc_aes_sbox sbox_3 (
        .byte_in(state_in[103:96]),
        .byte_out(state_out[103:96])
    );

    // S-box 4
    minisoc_aes_sbox sbox_4 (
        .byte_in(state_in[95:88]),
        .byte_out(state_out[95:88])
    );

    // S-box 5
    minisoc_aes_sbox sbox_5 (
        .byte_in(state_in[87:80]),
        .byte_out(state_out[87:80])
    );

    // S-box 6
    minisoc_aes_sbox sbox_6 (
        .byte_in(state_in[79:72]),
        .byte_out(state_out[79:72])
    );

    // S-box 7
    minisoc_aes_sbox sbox_7 (
        .byte_in(state_in[71:64]),
        .byte_out(state_out[71:64])
    );

    // S-box 8
    minisoc_aes_sbox sbox_8 (
        .byte_in(state_in[63:56]),
        .byte_out(state_out[63:56])
    );

    // S-box 9
    minisoc_aes_sbox sbox_9 (
        .byte_in(state_in[55:48]),
        .byte_out(state_out[55:48])
    );

    // S-box 10
    minisoc_aes_sbox sbox_10 (
        .byte_in(state_in[47:40]),
        .byte_out(state_out[47:40])
    );

    // S-box 11
    minisoc_aes_sbox sbox_11 (
        .byte_in(state_in[39:32]),
        .byte_out(state_out[39:32])
    );

    // S-box 12
    minisoc_aes_sbox sbox_12 (
        .byte_in(state_in[31:24]),
        .byte_out(state_out[31:24])
    );

    // S-box 13
    minisoc_aes_sbox sbox_13 (
        .byte_in(state_in[23:16]),
        .byte_out(state_out[23:16])
    );

    // S-box 14
    minisoc_aes_sbox sbox_14 (
        .byte_in(state_in[15:8]),
        .byte_out(state_out[15:8])
    );

    // S-box 15 - Último byte
    minisoc_aes_sbox sbox_15 (
        .byte_in(state_in[7:0]),
        .byte_out(state_out[7:0])
    );

endmodule
