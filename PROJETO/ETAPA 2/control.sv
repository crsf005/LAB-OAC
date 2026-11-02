`timescale 1ns / 1ps

module pl_control (
    input  logic [6:0] Opcode,
    output logic       ALUSrc,
    output logic       MemtoReg,
    output logic       RegWrite,
    output logic       MemRead,
    output logic       MemWrite,
    output logic       Branch,
    output logic [1:0] ALUOp,
    output logic [1:0] ALUSrcA
);

    localparam R_TYPE = 7'b0110011;
    localparam LOAD   = 7'b0000011;
    localparam STORE  = 7'b0100011;
    localparam BRANCH = 7'b1100011;
    localparam OP_IMM = 7'b0010011;
    localparam LUI    = 7'b0110111;
    localparam AUIPC  = 7'b0010111;

    always_comb begin
        ALUSrc   = 1'b0;
        MemtoReg = 1'b0;
        RegWrite = 1'b0;
        MemRead  = 1'b0;
        MemWrite = 1'b0;
        Branch   = 1'b0;
        ALUOp    = 2'b00;
        ALUSrcA  = 2'b00;

        case (Opcode)
            R_TYPE: begin
                RegWrite = 1'b1;
                ALUOp    = 2'b10;
            end

            OP_IMM: begin
                ALUSrc   = 1'b1;
                RegWrite = 1'b1;
                ALUOp    = 2'b11;
            end

            LOAD: begin
                ALUSrc   = 1'b1;
                MemtoReg = 1'b1;
                RegWrite = 1'b1;
                MemRead  = 1'b1;
                ALUOp    = 2'b00;
            end

            STORE: begin
                ALUSrc   = 1'b1;
                MemWrite = 1'b1;
                ALUOp    = 2'b00;
            end

            BRANCH: begin
                Branch   = 1'b1;
                ALUOp    = 2'b01;
            end

            LUI: begin
                ALUSrc   = 1'b1;
                RegWrite = 1'b1;
                ALUOp    = 2'b00;
                ALUSrcA  = 2'b10;
            end

            AUIPC: begin
                ALUSrc   = 1'b1;
                RegWrite = 1'b1;
                ALUOp    = 2'b00;
                ALUSrcA  = 2'b01;
            end

            default: ;
        endcase
    end

endmodule