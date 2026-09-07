
`timescale 1ns/1ps

module safecrack_fsm_tb;

    logic       clk;
    logic       rst_n;
    logic [3:0] btn;
    logic       unlocked;

   
    localparam [3:0] AZUL     = 4'b0001;
    localparam [3:0] AMARELO  = 4'b0010;
    localparam [3:0] VERDE    = 4'b0100;
    localparam [3:0] VERMELHO = 4'b1000;

    
    localparam [4:0] S_INIT     = 5'b00001;
    localparam [4:0] S_AZUL     = 5'b00010;
    localparam [4:0] S_AMARELO1 = 5'b00100;
    localparam [4:0] S_AMARELO2 = 5'b01000;
    localparam [4:0] S_UNLOCKED = 5'b10000;


    safecrack_fsm dut (
        .clk      (clk),
        .rst_n    (rst_n),
        .btn      (btn),
        .unlocked (unlocked)
    );


    initial clk = 0;
    always #10 clk = ~clk;


    task press_button(input logic [3:0] btn_val, input int hold_cycles);
        @(negedge clk);
        btn = btn_val;                 
        repeat (hold_cycles) @(posedge clk);
        
        @(negedge clk);
        btn = 4'b0000;                 
        repeat (3) @(posedge clk);     
    endtask


    task check_state(input logic [4:0] exp_state, input logic exp_unl, input string msg);
        @(negedge clk);
        if ((dut.state === exp_state) && (unlocked === exp_unl))
            $display("[PASS] %s | Estado: %b | unlocked: %b", msg, dut.state, unlocked);
        else
            $display("[FAIL] %s | Esperado Est/Unl: %b/%b | Obtido: %b/%b", 
                     msg, exp_state, exp_unl, dut.state, unlocked);
    endtask


    initial begin
        
        $dumpfile("safecrack_fsm.vcd");
        $dumpvars(0, safecrack_fsm_tb);

        
        rst_n = 1'b1;
        btn   = 4'b0000;  

        $display("\n=== Teste 1: Reset Inicial ===");
        rst_n = 1'b0;
        repeat (3) @(posedge clk);
        rst_n = 1'b1;
        @(posedge clk);
        check_state(S_INIT, 1'b0, "Apos reset -> S_INIT, trancado");


        $display("\n=== Teste 2: Erro quebra a sequencia ===");
        press_button(AZUL, 2);
        check_state(S_AZUL, 1'b0, "Apertou Azul -> Avança para S_AZUL");
        
        press_button(VERDE, 2);
        check_state(S_INIT, 1'b0, "Apertou Verde (Errado) -> Volta para S_INIT");


        $display("\n=== Teste 3: Botao segurado (nao deve avancar p/ Amarelo2) ===");
        press_button(AZUL, 2);
        press_button(AMARELO, 20); 
       
        check_state(S_AMARELO1, 1'b0, "Segurou Amarelo -> Fica no S_AMARELO1");
        
        
        rst_n = 1'b0; @(posedge clk); rst_n = 1'b1;


        $display("\n=== Teste 4: Sequencia Correta (Cofre Aberto) ===");
        press_button(AZUL, 2);
        check_state(S_AZUL, 1'b0, "1º Correto (Azul)");
        
        press_button(AMARELO, 2);
        check_state(S_AMARELO1, 1'b0, "2º Correto (Amarelo)");
        
        press_button(AMARELO, 2);
        check_state(S_AMARELO2, 1'b0, "3º Correto (Amarelo)");
        
        press_button(VERMELHO, 2);
        check_state(S_UNLOCKED, 1'b1, "4º Correto (Vermelho) -> UNLOCKED = 1");


        $display("\n=== Teste 5: Comportamento no S_UNLOCKED ===");
        press_button(AZUL | VERDE, 2); 
        check_state(S_UNLOCKED, 1'b1, "Botões ignorados, continua desbloqueado");


        $display("\n=== Teste 6: Reset (Trancar Cofre) ===");
        rst_n = 1'b0;
        repeat (2) @(posedge clk);
        rst_n = 1'b1;
        @(posedge clk);
        check_state(S_INIT, 1'b0, "Reset acionado -> Cofre trancado (S_INIT)");

        $display("\n=== Simulacao concluida ===\n");
        $finish;
    end

endmodule