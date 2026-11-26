
`timescale 1ns/1ps

// ============================================================================
// MiniSoC AES - Testbench da memoria compartilhada
// Semana 6 - AES Engine e memoria compartilhada
//
// Verificacao funcional de:
//   - Leitura e escrita sincronas.
//   - Ownership da memoria.
//   - Exclusao mutua entre os mestres.
//   - Comportamento no-change.
//   - Enderecamento completo.
//   - Organizacao dos blocos AES de 128 bits.
//
// A troca de ownership ocorre com ambos os clocks em nivel baixo,
// sem escritas em andamento, conforme a restricao desta etapa.
// ============================================================================

module minisoc_memory_tb;

    // ========================================================================
    // Constantes
    // ========================================================================

    localparam bit OWNER_EXT = 1'b0;
    localparam bit OWNER_AES = 1'b1;

    localparam int MEM_DEPTH = 1024;

    localparam realtime EXT_HALF_PERIOD = 2.5;
    localparam realtime AES_HALF_PERIOD = 0.5;

    // ========================================================================
    // Sinais do testbench
    // ========================================================================

    logic mem_sel_aes_i;

    // Interface externa.
    logic        mem_clk_i;
    logic [9:0]  ext_addr_i;
    logic [31:0] ext_wdata_i;
    logic        ext_wr_en_i;
    logic [31:0] ext_rdata_o;

    // Interface AES.
    logic        sys_clk_i;
    logic [9:0]  aes_addr_i;
    logic [31:0] aes_wdata_i;
    logic        aes_wr_en_i;
    logic [31:0] aes_rdata_o;

    // Contadores de verificacao.
    int checks;
    int failures;

    int group_checks;
    int group_failures;

    // Variaveis auxiliares.
    logic [31:0] previous_data;
    logic [31:0] word_data;

    logic [127:0] expected_block;
    logic [127:0] observed_block;

    logic [9:0] base_addr;

    // ========================================================================
    // Instanciacao do DUT
    // ========================================================================

    minisoc_memory dut (
        .mem_sel_aes_i (mem_sel_aes_i),

        .mem_clk_i     (mem_clk_i),
        .ext_addr_i    (ext_addr_i),
        .ext_wdata_i   (ext_wdata_i),
        .ext_wr_en_i   (ext_wr_en_i),
        .ext_rdata_o   (ext_rdata_o),

        .sys_clk_i     (sys_clk_i),
        .aes_addr_i    (aes_addr_i),
        .aes_wdata_i   (aes_wdata_i),
        .aes_wr_en_i   (aes_wr_en_i),
        .aes_rdata_o   (aes_rdata_o)
    );

    // ========================================================================
    // Tarefas de verificacao
    // ========================================================================

    task automatic check(
        input bit condition,
        input string message
    );
        checks++;

        if (!condition) begin
            failures++;

            $display(
                "[FAIL] %s (t=%0t)",
                message,
                $time
            );
        end
    endtask


    task automatic check_word(
        input logic [31:0] actual,
        input logic [31:0] expected,
        input string message
    );
        check(
            actual === expected,
            $sformatf(
                "%s | esperado=%08h obtido=%08h",
                message,
                expected,
                actual
            )
        );
    endtask


    task automatic begin_test(
        input string message
    );
        group_checks   = checks;
        group_failures = failures;

        $display("\n%s", message);
    endtask


    task automatic end_test();

        if (failures == group_failures) begin
            $display(
                "[PASS] %0d verificacoes aprovadas",
                checks - group_checks
            );
        end else begin
            $display(
                "[FAIL] %0d falha(s) em %0d verificacoes",
                failures - group_failures,
                checks - group_checks
            );
        end

    endtask

    // ========================================================================
    // Controle de ownership
    // ========================================================================

    task automatic select_owner(
        input bit owner
    );

        // Restricao temporaria da multiplexacao direta.
        // Ambos os clocks devem estar baixos.
        // Nenhum mestre deve estar escrevendo.

        if ((mem_clk_i   !== 1'b0) ||
            (sys_clk_i   !== 1'b0) ||
            (ext_wr_en_i !== 1'b0) ||
            (aes_wr_en_i !== 1'b0)) begin

            $fatal(
                1,
                "Tentativa de troca insegura de ownership"
            );
        end

        #0.1 mem_sel_aes_i = owner;

    endtask

    // ========================================================================
    // Geracao controlada dos clocks
    // ========================================================================

    task automatic rise_clock(
        input bit owner
    );

        if (owner == OWNER_AES) begin
            #AES_HALF_PERIOD sys_clk_i = 1'b1;
        end else begin
            #EXT_HALF_PERIOD mem_clk_i = 1'b1;
        end

    endtask


    task automatic fall_clock(
        input bit owner
    );

        if (owner == OWNER_AES) begin
            #AES_HALF_PERIOD sys_clk_i = 1'b0;
        end else begin
            #EXT_HALF_PERIOD mem_clk_i = 1'b0;
        end

    endtask


    task automatic pulse_clock(
        input bit owner
    );

        rise_clock(owner);
        fall_clock(owner);

    endtask

    // ========================================================================
    // Controle das interfaces
    // ========================================================================

    task automatic drive_port(
        input bit owner,
        input logic wr_en,
        input logic [9:0] addr,
        input logic [31:0] data
    );

        if (owner == OWNER_AES) begin
            aes_addr_i  = addr;
            aes_wdata_i = data;
            aes_wr_en_i = wr_en;
        end else begin
            ext_addr_i  = addr;
            ext_wdata_i = data;
            ext_wr_en_i = wr_en;
        end

    endtask

    // ========================================================================
    // Operacoes de escrita e leitura
    // ========================================================================

    task automatic write_word(
        input bit owner,
        input logic [9:0] addr,
        input logic [31:0] data
    );

        if (mem_sel_aes_i !== owner) begin
            $fatal(1, "Escrita solicitada pelo mestre sem ownership");
        end

        drive_port(owner, 1'b1, addr, data);

        pulse_clock(owner);

        // Finaliza a escrita.
        drive_port(owner, 1'b0, addr, data);

    endtask


    task automatic read_word(
        input bit owner,
        input logic [9:0] addr,
        output logic [31:0] data
    );

        if (mem_sel_aes_i !== owner) begin
            $fatal(1, "Leitura solicitada pelo mestre sem ownership");
        end

        drive_port(owner, 1'b0, addr, 32'd0);

        pulse_clock(owner);

        // A saida registrada ja foi atualizada.
        if (owner == OWNER_AES)
            data = aes_rdata_o;
        else
            data = ext_rdata_o;

    endtask


    task automatic expect_word(
        input bit owner,
        input logic [9:0] addr,
        input logic [31:0] expected,
        input string message
    );

        logic [31:0] actual;

        read_word(owner, addr, actual);

        check_word(actual, expected, message);

    endtask

    // ========================================================================
    // Geracao de padroes para teste da memoria completa
    // ========================================================================

    function automatic logic [31:0] memory_pattern(
        input logic [9:0] addr
    );

        return 32'hA5A5_0000 | {22'd0, addr};

    endfunction

    // ========================================================================
    // Sequencia principal de testes
    // ========================================================================

    initial begin : tests

        // Inicializacao apenas dos sinais do testbench.
        // O conteudo interno da memoria nao e inicializado.

        checks         = 0;
        failures       = 0;
        group_checks   = 0;
        group_failures = 0;

        mem_sel_aes_i = OWNER_EXT;

        mem_clk_i   = 1'b0;
        ext_addr_i  = 10'd0;
        ext_wdata_i = 32'd0;
        ext_wr_en_i = 1'b0;

        sys_clk_i   = 1'b0;
        aes_addr_i  = 10'd0;
        aes_wdata_i = 32'd0;
        aes_wr_en_i = 1'b0;

        $display("============================================================");
        $display(" MiniSoC AES - Testbench da Memoria - Semana 6");
        $display("============================================================");

        // ====================================================================
        // TESTE 01 - Interface externa
        // ====================================================================

        begin_test("[TESTE 01] Escrita e leitura pela interface externa");

        write_word(OWNER_EXT, 10'd0, 32'h0011_2233);
        write_word(OWNER_EXT, 10'd5, 32'hAABB_CCDD);
        write_word(OWNER_EXT, 10'd9, 32'h1234_5678);

        expect_word(
            OWNER_EXT, 10'd0, 32'h0011_2233,
            "Leitura externa do endereco 0"
        );

        expect_word(
            OWNER_EXT, 10'd5, 32'hAABB_CCDD,
            "Leitura externa do endereco 5"
        );

        expect_word(
            OWNER_EXT, 10'd9, 32'h1234_5678,
            "Leitura externa do endereco 9"
        );

        end_test();

        // ====================================================================
        // TESTE 02 - Interface AES
        // ====================================================================

        begin_test("[TESTE 02] Escrita e leitura pela interface AES");

        select_owner(OWNER_AES);

        write_word(OWNER_AES, 10'd10, 32'hDEAD_BEEF);
        write_word(OWNER_AES, 10'd11, 32'hCAFE_BABE);

        expect_word(
            OWNER_AES, 10'd10, 32'hDEAD_BEEF,
            "Leitura AES do endereco 10"
        );

        expect_word(
            OWNER_AES, 10'd11, 32'hCAFE_BABE,
            "Leitura AES do endereco 11"
        );

        end_test();

        // ====================================================================
        // TESTE 03 - Transferencia externa para AES
        // ====================================================================

        begin_test("[TESTE 03] Transferencia de ownership externa -> AES");

        select_owner(OWNER_EXT);

        write_word(OWNER_EXT, 10'd20, 32'h1122_3344);
        write_word(OWNER_EXT, 10'd21, 32'h5566_7788);

        select_owner(OWNER_AES);

        expect_word(
            OWNER_AES, 10'd20, 32'h1122_3344,
            "AES recupera palavra escrita pela interface externa"
        );

        expect_word(
            OWNER_AES, 10'd21, 32'h5566_7788,
            "Dados preservados apos transferencia"
        );

        end_test();

        // ====================================================================
        // TESTE 04 - Transferencia AES para externa
        // ====================================================================

        begin_test("[TESTE 04] Transferencia de ownership AES -> externa");

        write_word(OWNER_AES, 10'd20, 32'h99AA_BBCC);
        write_word(OWNER_AES, 10'd21, 32'hDDEE_FF00);

        select_owner(OWNER_EXT);

        expect_word(
            OWNER_EXT, 10'd20, 32'h99AA_BBCC,
            "Interface externa recupera palavra escrita pelo AES"
        );

        expect_word(
            OWNER_EXT, 10'd21, 32'hDDEE_FF00,
            "Resultado AES preservado apos transferencia"
        );

        end_test();

        // ====================================================================
        // TESTE 05 - Exclusao mutua
        // ====================================================================

        begin_test("[TESTE 05] Mestre nao selecionado nao acessa a memoria");

        // Caso A: interface externa possui a memoria.

        expect_word(
            OWNER_EXT, 10'd5, 32'hAABB_CCDD,
            "Conteudo inicial do endereco protegido"
        );

        previous_data = ext_rdata_o;

        // AES tenta escrever sem possuir a memoria.
        drive_port(OWNER_AES, 1'b1, 10'd5, 32'hFFFF_FFFF);

        // Endereco externo diferente da ultima leitura.
        drive_port(OWNER_EXT, 1'b0, 10'd0, 32'd0);

        pulse_clock(OWNER_AES);

        check_word(
            ext_rdata_o, previous_data,
            "Clock AES nao altera a saida quando externo possui a RAM"
        );

        expect_word(
            OWNER_EXT, 10'd5, 32'hAABB_CCDD,
            "Escrita do AES nao selecionado foi ignorada"
        );

        // Mestre selecionado escreve enquanto o outro solicita escrita.
        write_word(OWNER_EXT, 10'd6, 32'h1357_9BDF);

        expect_word(
            OWNER_EXT, 10'd6, 32'h1357_9BDF,
            "Escrita externa utiliza seus proprios sinais"
        );

        expect_word(
            OWNER_EXT, 10'd5, 32'hAABB_CCDD,
            "Endereco solicitado pelo AES permanece protegido"
        );

        aes_wr_en_i = 1'b0;

        // Caso B: AES possui a memoria.

        select_owner(OWNER_AES);

        expect_word(
            OWNER_AES, 10'd5, 32'hAABB_CCDD,
            "Conteudo inicial antes da tentativa externa"
        );

        previous_data = aes_rdata_o;

        drive_port(OWNER_EXT, 1'b1, 10'd5, 32'h0000_0000);

        drive_port(OWNER_AES, 1'b0, 10'd0, 32'd0);

        pulse_clock(OWNER_EXT);

        check_word(
            aes_rdata_o, previous_data,
            "Clock externo nao altera a saida quando AES possui a RAM"
        );

        expect_word(
            OWNER_AES, 10'd5, 32'hAABB_CCDD,
            "Escrita externa nao selecionada foi ignorada"
        );

        write_word(OWNER_AES, 10'd7, 32'h2468_ACE0);

        expect_word(
            OWNER_AES, 10'd7, 32'h2468_ACE0,
            "Escrita AES utiliza seus proprios sinais"
        );

        expect_word(
            OWNER_AES, 10'd5, 32'hAABB_CCDD,
            "Endereco solicitado pelo externo permanece protegido"
        );

        ext_wr_en_i = 1'b0;

        end_test();

        // ====================================================================
        // TESTE 06 - Comportamento no-change
        // ====================================================================

        begin_test("[TESTE 06] Saida registrada permanece durante escrita");

        // Interface externa.

        select_owner(OWNER_EXT);

        read_word(OWNER_EXT, 10'd0, previous_data);

        write_word(OWNER_EXT, 10'd30, 32'hABCD_EF01);

        check_word(
            ext_rdata_o, previous_data,
            "Saida externa mantida durante escrita"
        );

        expect_word(
            OWNER_EXT, 10'd30, 32'hABCD_EF01,
            "Novo valor recuperado em leitura posterior"
        );

        // Interface AES.

        select_owner(OWNER_AES);

        read_word(OWNER_AES, 10'd5, previous_data);

        write_word(OWNER_AES, 10'd31, 32'h1020_3040);

        check_word(
            aes_rdata_o, previous_data,
            "Saida AES mantida durante escrita"
        );

        expect_word(
            OWNER_AES, 10'd31, 32'h1020_3040,
            "Valor escrito pelo AES recuperado"
        );

        end_test();

        // ====================================================================
        // TESTE 07 - Leitura sincrona
        // ====================================================================

        begin_test("[TESTE 07] Temporizacao da leitura sincrona");

        // Interface externa.

        select_owner(OWNER_EXT);

        read_word(OWNER_EXT, 10'd0, previous_data);

        drive_port(OWNER_EXT, 1'b0, 10'd5, 32'd0);

        #0.1 check_word(
            ext_rdata_o, previous_data,
            "Mudanca de endereco nao altera imediatamente a saida externa"
        );

        rise_clock(OWNER_EXT);

        // Aguarda atualizacao das atribuicoes nao bloqueantes.
        #0.001 check_word(
            ext_rdata_o, 32'hAABB_CCDD,
            "Saida externa atualizada apos borda de subida"
        );

        fall_clock(OWNER_EXT);

        // Interface AES.

        select_owner(OWNER_AES);

        read_word(OWNER_AES, 10'd0, previous_data);

        drive_port(OWNER_AES, 1'b0, 10'd5, 32'd0);

        #0.1 check_word(
            aes_rdata_o, previous_data,
            "Mudanca de endereco nao altera imediatamente a saida AES"
        );

        rise_clock(OWNER_AES);

        #0.001 check_word(
            aes_rdata_o, 32'hAABB_CCDD,
            "Saida AES atualizada apos borda de subida"
        );

        fall_clock(OWNER_AES);

        end_test();

        // ====================================================================
        // TESTE 08 - Enderecos extremos
        // ====================================================================

        begin_test("[TESTE 08] Enderecos extremos da memoria");

        select_owner(OWNER_EXT);

        write_word(OWNER_EXT, 10'd0,    32'h1111_2222);
        write_word(OWNER_EXT, 10'd1023, 32'h3333_4444);

        expect_word(
            OWNER_EXT, 10'd0, 32'h1111_2222,
            "Primeiro endereco da memoria"
        );

        expect_word(
            OWNER_EXT, 10'd1023, 32'h3333_4444,
            "Ultimo endereco da memoria"
        );

        select_owner(OWNER_AES);

        expect_word(
            OWNER_AES, 10'd0, 32'h1111_2222,
            "AES acessa primeiro endereco"
        );

        expect_word(
            OWNER_AES, 10'd1023, 32'h3333_4444,
            "AES acessa ultimo endereco"
        );

        end_test();

        // ====================================================================
        // TESTE 09 - Memoria completa
        // ====================================================================

        begin_test("[TESTE 09] Escrita e leitura das 1024 posicoes");

        select_owner(OWNER_EXT);

        // Preenche toda a memoria pela interface externa.

        for (int i = 0; i < MEM_DEPTH; i++) begin

            write_word(
                OWNER_EXT,
                i[9:0],
                memory_pattern(i[9:0])
            );

        end

        select_owner(OWNER_AES);

        // AES verifica todas as palavras escritas.

        for (int i = 0; i < MEM_DEPTH; i++) begin

            expect_word(
                OWNER_AES,
                i[9:0],
                memory_pattern(i[9:0]),
                $sformatf("Leitura AES do endereco %0d", i)
            );

        end

        // AES sobrescreve todas as posicoes com outro padrao.

        for (int i = 0; i < MEM_DEPTH; i++) begin

            write_word(
                OWNER_AES,
                i[9:0],
                ~memory_pattern(i[9:0])
            );

        end

        select_owner(OWNER_EXT);

        // Interface externa verifica os novos valores.

        for (int i = 0; i < MEM_DEPTH; i++) begin

            expect_word(
                OWNER_EXT,
                i[9:0],
                ~memory_pattern(i[9:0]),
                $sformatf("Leitura externa do endereco %0d", i)
            );

        end

        end_test();

        // ====================================================================
        // TESTE 10 - Organizacao de blocos AES
        // ====================================================================

        begin_test("[TESTE 10] Armazenamento de blocos AES de 128 bits");

        // Verifica o primeiro e o ultimo bloco da memoria.

        for (int b = 0; b < 2; b++) begin

            if (b == 0) begin
                base_addr = 10'd0;

                expected_block =
                    128'h00112233445566778899AABBCCDDEEFF;
            end else begin
                base_addr = 10'd1020;

                expected_block =
                    128'hFFEEDDCCBBAA99887766554433221100;
            end

            select_owner(OWNER_EXT);

            // Word 0 = bits [127:96]
            // Word 1 = bits [95:64]
            // Word 2 = bits [63:32]
            // Word 3 = bits [31:0]

            for (int w = 0; w < 4; w++) begin

                write_word(
                    OWNER_EXT,
                    base_addr + 10'(w),
                    expected_block[127 - 32*w -: 32]
                );

            end

            select_owner(OWNER_AES);

            observed_block = 128'd0;

            // Reconstroi o bloco a partir das quatro palavras.

            for (int w = 0; w < 4; w++) begin

                read_word(
                    OWNER_AES,
                    base_addr + 10'(w),
                    word_data
                );

                observed_block[127 - 32*w -: 32] = word_data;

            end

            check(
                observed_block === expected_block,
                $sformatf(
                    "Bloco na base %0d | esperado=%032h obtido=%032h",
                    base_addr,
                    expected_block,
                    observed_block
                )
            );

        end

        end_test();

        // ====================================================================
        // Resultado final
        // ====================================================================

        $display("\n============================================================");
        $display(" Resultado do Testbench da Memoria Compartilhada");
        $display("============================================================");

        $display("Total de verificacoes : %0d", checks);
        $display("Total de falhas       : %0d", failures);

        if (failures == 0) begin

            $display(
                "PASS: minisoc_memory_tb - todas as verificacoes passaram"
            );

            $finish;

        end else begin

            $fatal(
                1,
                "FAIL: minisoc_memory_tb encontrou %0d falha(s)",
                failures
            );

        end

    end

    // ========================================================================
    // Timeout global
    // ========================================================================

    initial begin

        #100000 $fatal(
            1,
            "Timeout: testbench da memoria excedeu o tempo limite"
        );

    end

endmodule
