`timescale 1ns / 1ps

module pl_control (
    input  logic [6:0] Opcode,
    output logic       ALUSrc,
    output logic       MemtoReg,
    output logic       RegWrite,
    output logic       MemRead,
    output logic       MemWrite,
    output logic       Branch,
    output logic       Jump,       // [Etapa 03] Nova saida de controle para saltos incondicionais (JAL/JALR)
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
    localparam JAL    = 7'b1101111; // [Etapa 03] Opcode da instrucao JAL (Tipo-J)
    localparam JALR   = 7'b1100111; // [Etapa 03] Opcode da instrucao JALR (Tipo-I)

    always_comb begin
        ALUSrc   = 1'b0;
        MemtoReg = 1'b0;
        RegWrite = 1'b0;
        MemRead  = 1'b0;
        MemWrite = 1'b0;
        Branch   = 1'b0;
        Jump     = 1'b0;           // [Etapa 03] Valor padrao de Jump em nivel baixo
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

            // [Etapa 03] Decodificacao de JAL: ativa salto (Jump=1) e escrita do endereco de retorno PC+4 (RegWrite=1)
            JAL: begin
                RegWrite = 1'b1;
                Jump     = 1'b1;
                ALUOp    = 2'b00;
            end

            // [Etapa 03] Decodificacao de JALR: ativa salto, escrita de PC+4 e seleciona imediato (ALUSrc=1) para calcular rs1 + imm
            JALR: begin
                ALUSrc   = 1'b1;
                RegWrite = 1'b1;
                Jump     = 1'b1;
                ALUOp    = 2'b00;
            end

            default: ;
        endcase
    end

endmodule