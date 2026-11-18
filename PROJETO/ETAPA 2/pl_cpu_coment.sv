`timescale 1ns / 1ps

// Empacota todos os blocos principais para formar o processador completo.
// Conecta o Controle, o Datapath, a Memória (MMIO) e as interfaces de I/O da placa FPGA.
module pl_cpu (
    input  logic        clk,
    input  logic        rst_n,

    output logic [31:0] PC,

    // Portas mapeadas em memória (para uso em placa tipo DE2-115)
    input  logic [17:0] SW,
    input  logic [3:0]  KEY_IO,
    output logic [17:0] LEDR,
    output logic [8:0]  LEDG,
    output logic        UART_TXD,
    input  logic        UART_RXD,

    // Sinais de observabilidade (útil para testes em testbenches)
    output logic        wb_reg_write,
    output logic [4:0]  wb_reg_dst,
    output logic [31:0] wb_reg_data,
    output logic        mem_wr_en,
    output logic [7:0]  mem_wr_addr,
    output logic [31:0] mem_wr_data
);

    // Fios de interconexão entre Controle Principal (no ID) e o Datapath
    logic [6:0] opcode;
    logic       ALUSrc, MemtoReg, RegWrite, MemRead, MemWrite, Branch;
    logic [1:0] ALUOp, ALUSrcA;

    // Fios de interconexão retirados do estágio EX para alimentar o Controle da ALU
    logic [2:0] funct3_ex;
    logic [6:0] funct7_ex;
    logic [1:0] aluop_ex;
    logic [3:0] alu_cc;

    // Instancia a Unidade de Controle Principal
    pl_control ctrl (
        .Opcode   (opcode),
        .ALUSrc   (ALUSrc),
        .ALUSrcA  (ALUSrcA),
        .MemtoReg (MemtoReg),
        .RegWrite (RegWrite),
        .MemRead  (MemRead),
        .MemWrite (MemWrite),
        .Branch   (Branch),
        .ALUOp    (ALUOp)
    );

    // Instancia o Controle da ALU 
    pl_alu_ctrl alu_ctrl (
        .ALUOp     (aluop_ex),
        .Funct7    (funct7_ex),
        .Funct3    (funct3_ex),
        .Operation (alu_cc)
    );

    // Instancia o Datapath Pipelined (caminho de dados)
    pl_datapath datapath (
        .clk          (clk),
        .rst_n        (rst_n),
        .ALUSrc       (ALUSrc),
        .ALUSrcA      (ALUSrcA),
        .MemtoReg     (MemtoReg),
        .RegWrite     (RegWrite),
        .MemRead      (MemRead),
        .MemWrite     (MemWrite),
        .Branch       (Branch),
        .ALUOp        (ALUOp),
        .ALU_CC       (alu_cc),
        .Opcode       (opcode),
        .Funct3_EX    (funct3_ex),
        .Funct7_EX    (funct7_ex),
        .ALUOp_EX     (aluop_ex),
        .PC           (PC),
        // I/Os repassados
        .SW           (SW),
        .KEY          (KEY_IO),
        .LEDR         (LEDR),
        .LEDG         (LEDG),
        .UART_TXD     (UART_TXD),
        .UART_RXD     (UART_RXD),
        .wb_reg_write (wb_reg_write),
        .wb_reg_dst   (wb_reg_dst),
        .wb_reg_data  (wb_reg_data),
        .mem_wr_en    (mem_wr_en),
        .mem_wr_addr  (mem_wr_addr),
        .mem_wr_data  (mem_wr_data)
    );

endmodule