// =============================================================================
// pl_cpu_tb.sv
// Testbench -- RV32I pipelined (Etapa 03: Conjunto Base Completo)
//
// Instancia pl_cpu diretamente (sem PLL); gera clock e reset internamente.
//
// Programa de teste sugerido para Etapa 03 (instruction.mif / program.hex):
//   000: addi x1,  x0, -5      x1 = 0xFFFFFFFB (-5)
//   001: addi x2,  x0, 10      x2 = 0x0000000A (10)
//   002: sb   x1,  0(x0)       dmem[0] byte 0 <= 0xFB (store byte)
//   003: sh   x2,  2(x0)       dmem[0] half 1 <= 0x000A -> dmem[0] = 0x000A00FB
//   004: lb   x3,  0(x0)       x3 = 0xFFFFFFFB (-5, extensao de sinal)
//   005: lbu  x4,  0(x0)       x4 = 0x000000FB (251, extensao de zero)
//   006: lh   x5,  2(x0)       x5 = 0x0000000A (10, extensao de sinal)
//   007: lhu  x6,  2(x0)       x6 = 0x0000000A (10, extensao de zero)
//   008: bne  x1,  x2, +8      TOMADO (-5 != 10) -> salta 009
//   009: addi x7,  x0, 99      DESCARTADO (flush)
//   00A: blt  x1,  x2, +8      TOMADO (-5 < 10 signed) -> salta 00B
//   00B: addi x7,  x0, 99      DESCARTADO (flush)
//   00C: bge  x2,  x1, +8      TOMADO (10 >= -5 signed) -> salta 00D
//   00D: addi x7,  x0, 99      DESCARTADO (flush)
//   00E: bltu x2,  x1, +8      TOMADO (10 < 0xFFFFFFFB unsigned) -> salta 00F
//   00F: addi x7,  x0, 99      DESCARTADO (flush)
//   010: bgeu x1,  x2, +8      TOMADO (0xFFFFFFFB >= 10 unsigned) -> salta 011
//   011: addi x7,  x0, 99      DESCARTADO (flush)
//   012: jal  x8,  +8          TOMADO -> PC=0x048+8=0x050 (014), x8 = 0x04C (PC+4)
//   013: addi x7,  x0, 99      DESCARTADO (flush)
//   014: addi x9,  x8, 4       x9 = 0x050 (aponta para 014) -> x9 = x8 + 8 = 0x054 (015)
//   015: jalr x10, x9, 4       TOMADO -> PC=0x058 (016), x10 = 0x058 (PC+4)
//   016: addi x11, x0, 1       x11 = 1 (flag de sucesso)
//   017: beq  x0,  x0, 0       halt (loop infinito)
//
// O testbench:
//   1. Monitora cada escrita no banco de registradores (estagio WB)
//   2. Monitora cada escrita na memoria de dados (estagio MEM), refletindo SB/SH/SW
//   3. Detecta halt (periodo-3 de PC por HALT_CONFIRM ciclos consecutivos)
//   4. Faz dump do estado final dos registradores e da dmem[cite: 25]
//   5. Grava output.txt e compara com golden.txt[cite: 25]
// =============================================================================

`timescale 1ns / 1ps

module pl_cpu_tb;

    // =========================================================================
    // Parametros de Simulacao
    // =========================================================================
    localparam CLK_PERIOD   = 100;   // 10 MHz (100 ns) - mesmo clock do PLL na FPGA[cite: 25]
    localparam CLK_HALF     = CLK_PERIOD / 2;[cite: 25]
    localparam RESET_CYCLES = 4;     // Ciclos iniciais mantidos em reset[cite: 25]
    localparam MAX_CYCLES   = 2000;  // Timeout de seguranca contra loops infinitos[cite: 25]

    // =========================================================================
    // Sinais de Interface com o DUT (pl_cpu)
    // =========================================================================
    logic        clk, rst_n;[cite: 25]
    logic [31:0] PC;[cite: 25]
    logic [17:0] SW       = 18'h15555;   // Chaves com padrao alternado[cite: 25]
    logic [3:0]  KEY      = 4'hF;        // Botoes soltos (ativo-baixo)[cite: 25]
    logic [17:0] LEDR;[cite: 25]
    logic [8:0]  LEDG;[cite: 25]
    logic        UART_TXD;[cite: 25]
    logic        UART_RXD = 1'b1;        // Linha serial em repouso (idle = 1)[cite: 25]

    // Sinais de depuracao expostos pela CPU
    logic        wb_reg_write;[cite: 25]
    logic [4:0]  wb_reg_dst;[cite: 25]
    logic [31:0] wb_reg_data;[cite: 25]
    logic        mem_wr_en;[cite: 25]
    logic [7:0]  mem_wr_addr;[cite: 25]
    logic [31:0] mem_wr_data;[cite: 25]

    // =========================================================================
    // Instanciacao do Processador (DUT)
    // =========================================================================
    pl_cpu dut (
        .clk          (clk),[cite: 25]
        .rst_n        (rst_n),[cite: 25]
        .PC           (PC),[cite: 25]
        .SW           (SW),[cite: 25]
        .KEY_IO       (KEY),[cite: 25]
        .LEDR         (LEDR),[cite: 25]
        .LEDG         (LEDG),[cite: 25]
        .UART_TXD     (UART_TXD),[cite: 25]
        .UART_RXD     (UART_RXD),[cite: 25]
        .wb_reg_write (wb_reg_write),[cite: 25]
        .wb_reg_dst   (wb_reg_dst),[cite: 25]
        .wb_reg_data  (wb_reg_data),[cite: 25]
        .mem_wr_en    (mem_wr_en),[cite: 25]
        .mem_wr_addr  (mem_wr_addr),[cite: 25]
        .mem_wr_data  (mem_wr_data)[cite: 25]
    );

    // =========================================================================
    // Geracao de Clock e Reset
    // =========================================================================
    initial clk = 1'b0;[cite: 25]
    always #(CLK_HALF) clk = ~clk;[cite: 25]

    initial begin
        rst_n = 1'b0;[cite: 25]
        repeat (RESET_CYCLES) @(posedge clk);[cite: 25]
        @(negedge clk);[cite: 25]
        rst_n = 1'b1;[cite: 25]
    end

    // =========================================================================
    // Descritores de Arquivo
    // =========================================================================
    integer out_fd;[cite: 25]

    // =========================================================================
    // Monitor de Escrita no Banco de Registradores (Estagio WB)
    // =========================================================================
    // Captura todas as gravacoes validas (exclui x0, que e hardwired em 0)
    always @(posedge clk) begin
        if (rst_n && wb_reg_write && wb_reg_dst != 5'b0) begin[cite: 25]
            $display("[WB]  REG x%02d <= 0x%08X (%0d)", wb_reg_dst, wb_reg_data, $signed(wb_reg_data));
            $fdisplay(out_fd, "REG %2d = 0x%08X", wb_reg_dst, wb_reg_data);[cite: 25]
        end
    end

    // =========================================================================
    // Monitor de Escrita na Memoria de Dados (Estagio MEM) - Atualizado Etapa 03
    // =========================================================================
    // Como SB e SH modificam apenas 8 ou 16 bits da palavra de 32 bits,
    // aguardamos #1 ns apos a borda de subida do clock para ler o valor real
    // consolidado dentro da RAM (dut.datapath.dmem.ram[addr]).
    always @(posedge clk) begin
        if (rst_n && mem_wr_en) begin[cite: 25]
            #1;
            $display("[MEM] dmem[%03d] <= 0x%08X (Dado bruto barramento: 0x%08X)",
                     mem_wr_addr, dut.datapath.dmem.ram[mem_wr_addr], mem_wr_data);
            $fdisplay(out_fd, "MEM[%3d] = 0x%08X", mem_wr_addr, dut.datapath.dmem.ram[mem_wr_addr]);
        end
    end

    // =========================================================================
    // Deteccao de Halt e Controle Principal da Simulacao
    // =========================================================================
    // No pipeline com resolucao de desvio no estagio EX, um loop "beq x0, x0, 0"
    // busca duas instrucoes seguintes antes do flush, gerando uma oscilacao de
    // periodo 3 no PC: H -> H+4 -> H+8 -> H -> ...[cite: 25]
    localparam BRANCH_PERIOD = 3;[cite: 25]
    localparam HALT_CONFIRM  = 9;    // 3 ciclos completos de oscilacao confirmam o halt[cite: 25]

    logic [31:0] pc_hist [0:BRANCH_PERIOD];[cite: 25]
    integer      halt_cnt;[cite: 25]
    integer      cycle_cnt;[cite: 25]
    logic        halted;[cite: 25]
    integer      i, j, errors;[cite: 25]

    initial begin
        out_fd    = $fopen("output.txt", "w");[cite: 25]
        halt_cnt  = 0;[cite: 25]
        cycle_cnt = 0;[cite: 25]
        halted    = 1'b0;[cite: 25]

        for (j = 0; j <= BRANCH_PERIOD; j++) pc_hist[j] = 32'hFFFFFFFF;[cite: 25]

        // Aguarda liberacao do reset[cite: 25]
        @(posedge rst_n);[cite: 25]
        $display("=== Inicio da Simulacao (Etapa 03 - RV32I Completo) ===");

        // Executa ciclo a ciclo ate detectar halt ou atingir timeout[cite: 25]
        while (!halted && cycle_cnt < MAX_CYCLES) begin[cite: 25]
            @(posedge clk);[cite: 25]
            #1; // Aguarda estabilizacao das atribuicoes nao-bloqueantes (NBA)[cite: 25]

            cycle_cnt++;[cite: 25]

            // Atualiza historico deslizante do PC[cite: 25]
            for (j = BRANCH_PERIOD; j > 0; j--)[cite: 25]
                pc_hist[j] = pc_hist[j-1];[cite: 25]
            pc_hist[0] = PC;[cite: 25]

            // Verifica repeticao periodica caracteristica do halt[cite: 25]
            if (pc_hist[0] != 32'hFFFFFFFF &&[cite: 25]
                pc_hist[BRANCH_PERIOD] != 32'hFFFFFFFF &&[cite: 25]
                pc_hist[0] == pc_hist[BRANCH_PERIOD]) begin[cite: 25]
                halt_cnt++;[cite: 25]
                if (halt_cnt >= HALT_CONFIRM)[cite: 25]
                    halted = 1'b1;[cite: 25]
            end else begin
                halt_cnt = 0;[cite: 25]
            end
        end

        if (cycle_cnt >= MAX_CYCLES)[cite: 25]
            $display("AVISO: timeout apos %0d ciclos (halt nao detectado).", MAX_CYCLES);[cite: 25]
        else
            $display("Halt detectado em PC=0x%08X apos %0d ciclos.", PC, cycle_cnt);[cite: 25]

        // =====================================================================
        // Dump do Estado Final (Registradores e Memoria)
        // =====================================================================
        $display("\n--- Estado final dos registradores (nao-zero) ---");[cite: 25]
        $fdisplay(out_fd, "--- estado final ---");[cite: 25]

        for (i = 1; i < 32; i++) begin[cite: 25]
            if (dut.datapath.regfile.rf[i] !== 32'b0) begin[cite: 25]
                $display("  x%02d = 0x%08X (%0d)",
                         i, dut.datapath.regfile.rf[i], $signed(dut.datapath.regfile.rf[i]));
                $fdisplay(out_fd, "FINAL REG %2d = 0x%08X", i, dut.datapath.regfile.rf[i]);[cite: 25]
            end
        end

        $display("\n--- Estado final da dmem (primeiras 16 palavras nao-zero) ---");
        for (i = 0; i < 16; i++) begin[cite: 25]
            if (dut.datapath.dmem.ram[i] !== 32'b0) begin[cite: 25]
                $display("  dmem[%02d] = 0x%08X", i, dut.datapath.dmem.ram[i]);[cite: 25]
                $fdisplay(out_fd, "FINAL MEM[%3d] = 0x%08X", i, dut.datapath.dmem.ram[i]);[cite: 25]
            end
        end

        $fclose(out_fd);[cite: 25]

        // =====================================================================
        // Comparacao Automatica com golden.txt
        // =====================================================================
        $display("\n--- Comparacao com golden.txt ---");[cite: 25]
        errors = compare_with_golden();[cite: 25]
        if (errors == 0)[cite: 25]
            $display("PASS: saida corresponde ao golden.");[cite: 25]
        else
            $display("FAIL: %0d diferenca(s) encontrada(s).", errors);[cite: 25]

        $stop;[cite: 25]
    end

    // =========================================================================
    // Funcao Auxiliar: Compara output.txt linha a linha com golden.txt
    // =========================================================================
    function automatic integer compare_with_golden();[cite: 25]
        integer gfd, ofd;[cite: 25]
        string  gline, oline;[cite: 25]
        integer errs;[cite: 25]
        errs = 0;[cite: 25]

        gfd = $fopen("golden.txt", "r");[cite: 25]
        ofd = $fopen("output.txt", "r");[cite: 25]

        if (gfd == 0) begin[cite: 25]
            $display("AVISO: golden.txt nao encontrado -- pulando comparacao.");[cite: 25]
            return 0;[cite: 25]
        end
        if (ofd == 0) begin[cite: 25]
            $display("ERRO: output.txt nao pode ser aberto.");[cite: 25]
            return 1;[cite: 25]
        end

        while (!$feof(gfd)) begin[cite: 25]
            void'($fgets(gline, gfd));[cite: 25]
            void'($fgets(oline, ofd));[cite: 25]
            if (gline != oline) begin[cite: 25]
                $display("DIFF golden: %s  output: %s", gline, oline);[cite: 25]
                errs++;[cite: 25]
            end
        end

        $fclose(gfd);[cite: 25]
        $fclose(ofd);[cite: 25]
        return errs;[cite: 25]
    endfunction

endmodule