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
            // [Base] Acesso à memória (LW, SW): soma endereço base + deslocamento
            2'b00: Operation = 4'd01;   

            // [Base] Desvio condicional (BEQ): subtrai operandos para testar Zero
            2'b01: Operation = 4'd02;   

            // Instruções Tipo-R (Base + Etapa 01):
            // decodifica a operação usando Funct3 e o bit modificador Funct7[5]
            2'b10: begin                
                case (Funct3)
                    3'h0: Operation = Funct7[5] ? 4'd02 : 4'd01; // [Base] Funct7[5]=1 -> SUB; Funct7[5]=0 -> ADD
                    3'h1: Operation = 4'd06;                     // [Etapa 01] SLL (shift lógico à esquerda)
                    3'h2: Operation = 4'd11;                     // [Base] SLT (menor que com sinal)
                    3'h3: Operation = 4'd12;                     // [Etapa 01] SLTU (menor que sem sinal)
                    3'h4: Operation = 4'd03;                     // [Etapa 01] XOR (OU-exclusivo)
                    3'h5: Operation = Funct7[5] ? 4'd08 : 4'd07; // [Etapa 01] Funct7[5]=1 -> SRA; Funct7[5]=0 -> SRL
                    3'h6: Operation = 4'd04;                     // [Base] OR
                    3'h7: Operation = 4'd05;                     // [Base] AND
                    default: Operation = 4'd01;
                endcase
            end

            // Caso padrão: executa ADD
            default: Operation = 4'd01;
        endcase
    end

endmodule
