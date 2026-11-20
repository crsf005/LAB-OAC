// =============================================================================
// pl_alu_ctrl.sv
// Unidade de Controle da ALU (Decodificador de 2º Nível) -- RV32I Pipelined
//
// Traduz ALUOp e os campos Funct3/Funct7 no código Operation de 4 bits da ALU.
// =============================================================================

`timescale 1ns / 1ps

module pl_alu_ctrl (
    input  logic [1:0] ALUOp,     
    input  logic [6:0] Funct7,    
    input  logic [2:0] Funct3,    
    output logic [3:0] Operation  
);

    always_comb begin
        case (ALUOp)
            2'b00: Operation = 4'd01; // [Etapa 02] Agora também atende LUI e AUIPC (soma)

            2'b01: Operation = 4'd02;

            2'b10: begin
                case (Funct3)
                    3'h0: Operation = Funct7[5] ? 4'd02 : 4'd01;
                    3'h1: Operation = 4'd06;
                    3'h2: Operation = 4'd11;
                    3'h3: Operation = 4'd12;
                    3'h4: Operation = 4'd03;
                    3'h5: Operation = Funct7[5] ? 4'd08 : 4'd07;
                    3'h6: Operation = 4'd04;
                    3'h7: Operation = 4'd05;
                    default: Operation = 4'd01;
                endcase
            end

            // [Etapa 02] Novo ramo para instruções Tipo-I (OP-IMM)
            2'b11: begin
                case (Funct3)
                    3'h0: Operation = 4'd01;                     // [Etapa 02] ADDI: força ADD ignorando Funct7[5] (evita SUB em imediato negativo)
                    3'h1: Operation = 4'd06;                     // [Etapa 02] SLLI
                    3'h2: Operation = 4'd11;                     // [Etapa 02] SLTI
                    3'h3: Operation = 4'd12;                     // [Etapa 02] SLTIU
                    3'h4: Operation = 4'd03;                     // [Etapa 02] XORI
                    3'h5: Operation = Funct7[5] ? 4'd08 : 4'd07; // [Etapa 02] Funct7[5]=1 -> SRAI; Funct7[5]=0 -> SRLI
                    3'h6: Operation = 4'd04;                     // [Etapa 02] ORI
                    3'h7: Operation = 4'd05;                     // [Etapa 02] ANDI
                    default: Operation = 4'd01;
                endcase
            end

            default: Operation = 4'd01;
        endcase
    end

endmodule