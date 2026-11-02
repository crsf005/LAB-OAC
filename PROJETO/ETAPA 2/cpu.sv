`timescale 1ns / 1ps

module pl_cpu (
    input  logic        clk,
    input  logic        rst_n,

    output logic [31:0] PC,

    input  logic [17:0] SW,
    input  logic [3:0]  KEY_IO,
    output logic [17:0] LEDR,
    output logic [8:0]  LEDG,
    output logic        UART_TXD,
    input  logic        UART_RXD,

    output logic        wb_reg_write,
    output logic [4:0]  wb_reg_dst,
    output logic [31:0] wb_reg_data,
    output logic        mem_wr_en,
    output logic [7:0]  mem_wr_addr,
    output logic [31:0] mem_wr_data
);

    logic [6:0] opcode;

    logic       ALUSrc, MemtoReg, RegWrite, MemRead, MemWrite, Branch;
    logic [1:0] ALUOp;
    logic [1:0] ALUSrcA;

    logic [2:0] funct3_ex;
    logic [6:0] funct7_ex;
    logic [1:0] aluop_ex;
    logic [3:0] alu_cc;

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

    pl_alu_ctrl alu_ctrl (
        .ALUOp     (aluop_ex),
        .Funct7    (funct7_ex),
        .Funct3    (funct3_ex),
        .Operation (alu_cc)
    );

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