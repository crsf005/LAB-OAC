// =============================================================================
// pl_alu_ctrl.sv
// Unidade de Controle da ALU (Decodificador de 2º Nível) -- RV32I Pipelined
//
// Traduz o sinal genérico ALUOp (vindo do controlador principal via ID/EX)
// e os campos Funct3/Funct7 da instrução no código Operation de 4 bits.
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
            // Instruções de acesso à memória (LW, SW, LB, LH, SB, SH):
            // força soma (ADD) para calcular endereço base + deslocamento
            2'b00: Operation = 4'd01;   

            // Instruções de desvio condicional (BEQ, BNE):
            // força subtração (SUB) para testar igualdade via flag Zero
            2'b01: Operation = 4'd02;   

            // Instruções aritméticas, lógicas e de deslocamento (Tipo-R / OP-IMM):
            // decodifica a operação exata usando Funct3 e o bit modificador Funct7[5]
            2'b10: begin                
                case (Funct3)
                    3'h0: Operation = Funct7[5] ? 4'd02 : 4'd01; // Funct7[5]=1 -> SUB (4'd02); Funct7[5]=0 -> ADD (4'd01)
                    3'h1: Operation = 4'd06;                     // SLL / SLLI 
                    3'h2: Operation = 4'd11;                     // SLT / SLTI 
                    3'h3: Operation = 4'd12;                     // SLTU / SLTIU 
                    3'h4: Operation = 4'd03;                     // XOR / XORI (OU exclusivo)
                    3'h5: Operation = Funct7[5] ? 4'd08 : 4'd07; // Funct7[5]=1 -> SRA/SRAI (4'd08); Funct7[5]=0 -> SRL/SRLI (4'd07)
                    3'h6: Operation = 4'd04;                     // OR / ORI 
                    3'h7: Operation = 4'd05;                     // AND / ANDI 
                    default: Operation = 4'd01;
                endcase
            end

            // Caso padrão: executa ADD
            default: Operation = 4'd01;
        endcase
    end

endmodule
