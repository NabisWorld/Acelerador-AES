module porta_and_tb;

    logic inA;
    logic inB;
    logic out;

    // Instância do DUT
    porta_and dut (
        .inA(inA),
        .inB(inB),
        .out(out)
    );

    initial begin

        $display("================================");
        $display(" Teste da porta AND");
        $display("================================");

        // Caso 1: 0 AND 0 = 0
        inA = 0;
        inB = 0;
        #10;

        if (out !== 0)
            $error("ERRO: 0 AND 0 deveria resultar em 0");
        else
            $display("PASS: 0 AND 0 = %b", out);


        // Caso 2: 0 AND 1 = 0
        inA = 0;
        inB = 1;
        #10;

        if (out !== 0)
            $error("ERRO: 0 AND 1 deveria resultar em 0");
        else
            $display("PASS: 0 AND 1 = %b", out);


        // Caso 3: 1 AND 0 = 0
        inA = 1;
        inB = 0;
        #10;

        if (out !== 0)
            $error("ERRO: 1 AND 0 deveria resultar em 0");
        else
            $display("PASS: 1 AND 0 = %b", out);


        // Caso 4: 1 AND 1 = 1
        inA = 1;
        inB = 1;
        #10;

        if (out !== 1)
            $error("ERRO: 1 AND 1 deveria resultar em 1");
        else
            $display("PASS: 1 AND 1 = %b", out);


        $display("================================");
        $display(" Simulacao concluida");
        $display("================================");

        $finish;

    end

endmodule