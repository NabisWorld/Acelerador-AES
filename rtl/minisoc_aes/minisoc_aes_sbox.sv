// S-BOX AES-128

module minisoc_aes_sbox (
    input  logic [7:0] byte_in,
    output logic [7:0] byte_out
);

    logic [127:0] linha_selecionada;

    // Lógica combinacional da S-box
    always_comb begin
        case (byte_in[7:4])

            4'h0: linha_selecionada = 128'h637C777B_F26B6FC5_3001672B_FED7AB76;

            4'h1: linha_selecionada = 128'hCA82C97D_FA5947F0_ADD4A2AF_9CA472C0;

            4'h2: linha_selecionada = 128'hB7FD9326_363FF7CC_34A5E5F1_71D83115;

            4'h3: linha_selecionada = 128'h04C723C3_1896059A_071280E2_EB27B275;

            4'h4: linha_selecionada = 128'h09832C1A_1B6E5AA0_523BD6B3_29E32F84;

            4'h5: linha_selecionada = 128'h53D100ED_20FCB15B_6ACBBE39_4A4C58CF;

            4'h6: linha_selecionada = 128'hD0EFAAFB_434D3385_45F9027F_503C9FA8;

            4'h7: linha_selecionada = 128'h51A3408F_929D38F5_BCB6DA21_10FFF3D2;

            4'h8: linha_selecionada = 128'hCD0C13EC_5F974417_C4A77E3D_645D1973;

            4'h9: linha_selecionada = 128'h60814FDC_222A9088_46EEB814_DE5E0BDB;

            4'hA: linha_selecionada = 128'hE0323A0A_4906245C_C2D3AC62_9195E479;

            4'hB: linha_selecionada = 128'hE7C8376D_8DD54EA9_6C56F4EA_657AAE08;

            4'hC: linha_selecionada = 128'hBA78252E_1CA6B4C6_E8DD741F_4BBD8B8A;

            4'hD: linha_selecionada = 128'h703EB566_4803F60E_613557B9_86C11D9E;

            4'hE: linha_selecionada = 128'hE1F89811_69D98E94_9B1E87E9_CE5528DF;

            4'hF: linha_selecionada = 128'h8CA1890D_BFE64268_41992D0F_B054BB16;

            default: linha_selecionada = 128'h0;

        endcase
    end

//selecao da coluna
    assign byte_out =
        linha_selecionada[127 - (8 * byte_in[3:0]) -: 8];

endmodule
