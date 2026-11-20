// =============================================================================
// pl_control.sv
// Unidade de Controle Principal -- RV32I Pipelined (Estágio ID)
//
// Decodifica o Opcode da instrução e gera os sinais de controle do datapath.
// =============================================================================

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
    output logic [1:0] ALUSrcA   // [Etapa 02] Nova saída: seleciona SrcA (00=rs1, 01=PC, 10=Zero)
);

    localparam R_TYPE = 7'b0110011;
    localparam LOAD   = 7'b0000011;
    localparam STORE  = 7'b0100011;
    localparam BRANCH = 7'b1100011;
    localparam OP_IMM = 7'b0010011; // [Etapa 02] Opcode das instruções Tipo-I (ADDI, ANDI, ORI, etc.)
    localparam LUI    = 7'b0110111; // [Etapa 02] Opcode da instrução LUI
    localparam AUIPC  = 7'b0010111; // [Etapa 02] Opcode da instrução AUIPC

    always_comb begin
        ALUSrc   = 1'b0;
        MemtoReg = 1'b0;
        RegWrite = 1'b0;
        MemRead  = 1'b0;
        MemWrite = 1'b0;
        Branch   = 1'b0;
        ALUOp    = 2'b00;
        ALUSrcA  = 2'b00; // [Etapa 02] Valor padrão (seleciona registrador rs1)

        case (Opcode)
            R_TYPE: begin
                RegWrite = 1'b1;
                ALUOp    = 2'b10;
            end
            // [Etapa 02] Decodificação das instruções Tipo-I (OP-IMM)
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
            // [Etapa 02] Decodificação de LUI: força SrcA = 0 (ALUSrcA = 2'b10) para calcular 0 + ImmU
            LUI: begin
                ALUSrc   = 1'b1;
                RegWrite = 1'b1;
                ALUOp    = 2'b00;
                ALUSrcA  = 2'b10;
            end
            // [Etapa 02] Decodificação de AUIPC: força SrcA = PC (ALUSrcA = 2'b01) para calcular PC + ImmU
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