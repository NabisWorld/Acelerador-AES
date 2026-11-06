module minisoc_aes_inv_sbox (
    input  logic [7:0] byte_in,
    output logic [7:0] byte_out
);

    logic [127:0] linha_selecionada;

    // S-box inversa do AES (FIPS-197).
    // Os quatro bits superiores selecionam a linha.
    always_comb begin
        case (byte_in[7:4])

            4'h0: linha_selecionada = 128'h52096AD5_3036A538_BF40A39E_81F3D7FB;
            4'h1: linha_selecionada = 128'h7CE33982_9B2FFF87_348E4344_C4DEE9CB;
            4'h2: linha_selecionada = 128'h547B9432_A6C2233D_EE4C950B_42FAC34E;
            4'h3: linha_selecionada = 128'h082EA166_28D924B2_765BA249_6D8BD125;
            4'h4: linha_selecionada = 128'h72F8F664_86689816_D4A45CCC_5D65B692;
            4'h5: linha_selecionada = 128'h6C704850_FDEDB9DA_5E154657_A78D9D84;
            4'h6: linha_selecionada = 128'h90D8AB00_8CBCD30A_F7E45805_B8B34506;
            4'h7: linha_selecionada = 128'hD02C1E8F_CA3F0F02_C1AFBD03_01138A6B;
            4'h8: linha_selecionada = 128'h3A911141_4F67DCEA_97F2CFCE_F0B4E673;
            4'h9: linha_selecionada = 128'h96AC7422_E7AD3585_E2F937E8_1C75DF6E;
            4'hA: linha_selecionada = 128'h47F11A71_1D29C589_6FB7620E_AA18BE1B;
            4'hB: linha_selecionada = 128'hFC563E4B_C6D27920_9ADBC0FE_78CD5AF4;
            4'hC: linha_selecionada = 128'h1FDDA833_8807C731_B1121059_2780EC5F;
            4'hD: linha_selecionada = 128'h60517FA9_19B54A0D_2DE57A9F_93C99CEF;
            4'hE: linha_selecionada = 128'hA0E03B4D_AE2AF5B0_C8EBBB3C_83539961;
            4'hF: linha_selecionada = 128'h172B047E_BA77D626_E1691463_55210C7D;

            default: linha_selecionada = 128'h0;

        endcase
    end

    // Os quatro bits inferiores selecionam o byte.
    assign byte_out =
        linha_selecionada[127 - (8 * byte_in[3:0]) -: 8];

endmodule
