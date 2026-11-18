`timescale 1ns / 1ps

// Unidade de Controle Principal atuando no estágio ID (Decode).
// Identifica a família da instrução pelo Opcode e levanta as flags que 
// configurarão os multiplexadores e memórias pelo resto do pipeline.

module pl_control (
    input  logic [6:0] Opcode,   // Bits [6:0] da instrução
    output logic       ALUSrc,   // Define se operando B é registrador (0) ou imediato (1)
    output logic       MemtoReg, // Define se grava no banco o dado da ALU (0) ou da Memória (1)
    output logic       RegWrite, // Habilita escrita no banco de registradores (estágio WB)
    output logic       MemRead,  // Habilita leitura na memória de dados (estágio MEM)
    output logic       MemWrite, // Habilita escrita na memória de dados (estágio MEM)
    output logic       Branch,   // Indica se a instrução é um salto condicional
    output logic [1:0] ALUOp,    // Envia o tipo base da operação para a pl_alu_ctrl
    output logic [1:0] ALUSrcA   // Define operando A: 00=Reg, 01=PC (AUIPC), 10=Zero (LUI)
);

    // Mapeamento dos opcodes RISC-V (bits menos significativos da instrução)
    localparam R_TYPE = 7'b0110011;
    localparam LOAD   = 7'b0000011;
    localparam STORE  = 7'b0100011;
    localparam BRANCH = 7'b1100011;
    localparam OP_IMM = 7'b0010011;
    localparam LUI    = 7'b0110111;
    localparam AUIPC  = 7'b0010111;

    always_comb begin
        // Padrão de segurança para evitar latches indesejados no hardware
        ALUSrc   = 1'b0;
        MemtoReg = 1'b0;
        RegWrite = 1'b0;
        MemRead  = 1'b0;
        MemWrite = 1'b0;
        Branch   = 1'b0;
        ALUOp    = 2'b00;
        ALUSrcA  = 2'b00;

        // Ativação das lógicas específicas por tipo de instrução
        case (Opcode)
            R_TYPE: begin
                RegWrite = 1'b1;
                ALUOp    = 2'b10;
            end
            OP_IMM: begin
                ALUSrc   = 1'b1;  // Opera com imediato
                RegWrite = 1'b1;
                ALUOp    = 2'b11;
            end
            LOAD: begin
                ALUSrc   = 1'b1;  // Endereço = base_reg + imm
                MemtoReg = 1'b1;  // Traz o valor da memória para gravar
                RegWrite = 1'b1;
                MemRead  = 1'b1;
                ALUOp    = 2'b00; // Soma para calcular endereço
            end
            STORE: begin
                ALUSrc   = 1'b1;  // Endereço = base_reg + imm
                MemWrite = 1'b1;  // Escreve na memória
                ALUOp    = 2'b00; 
            end
            BRANCH: begin
                Branch   = 1'b1;
                ALUOp    = 2'b01; // Subtração para a flag Zero
            end
            LUI: begin
                ALUSrc   = 1'b1;
                RegWrite = 1'b1;
                ALUOp    = 2'b00;
                ALUSrcA  = 2'b10; // Operando A vira ZERO (ALU fará 0 + Imediato_Superior)
            end
            AUIPC: begin
                ALUSrc   = 1'b1;
                RegWrite = 1'b1;
                ALUOp    = 2'b00;
                ALUSrcA  = 2'b01; // Operando A vira PC atual (ALU fará PC + Imediato_Superior)
            end
            default: ;
        endcase
    end

endmodule