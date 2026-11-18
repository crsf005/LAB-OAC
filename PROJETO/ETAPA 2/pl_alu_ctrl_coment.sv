`timescale 1ns / 1ps

module pl_alu_ctrl (
    input  logic [1:0] ALUOp,     
    input  logic [6:0] Funct7,    
    input  logic [2:0] Funct3,    
    output logic [3:0] Operation  
);

    always_comb begin
        case (ALUOp)
            2'b00: Operation = 4'd01; // Memória (Load/Store) ou Tipos-U (LUI/AUIPC): sempre soma (ADD)

            2'b01: Operation = 4'd02; // Branches (BEQ): sempre subtrai (SUB) para testar igualdade

            2'b10: begin // Instruções Tipo-R (registradores). Depende do Funct3 e Funct7.
                case (Funct3)
                    3'h0: Operation = Funct7[5] ? 4'd02 : 4'd01; // Diferencia SUB (Funct7[5]=1) e ADD (0)
                    3'h1: Operation = 4'd06;                     // SLL
                    3'h2: Operation = 4'd11;                     // SLT
                    3'h3: Operation = 4'd12;                     // SLTU
                    3'h4: Operation = 4'd03;                     // XOR
                    3'h5: Operation = Funct7[5] ? 4'd08 : 4'd07; // Diferencia SRA (1) e SRL (0)
                    3'h6: Operation = 4'd04;                     // OR
                    3'h7: Operation = 4'd05;                     // AND
                    default: Operation = 4'd01;
                endcase
            end

            2'b11: begin // Instruções Tipo-I (imediato lógico/aritmético).
                case (Funct3)
                    3'h0: Operation = 4'd01;                     // ADDI (sempre soma, ignora Funct7)
                    3'h1: Operation = 4'd06;                     // SLLI
                    3'h2: Operation = 4'd11;                     // SLTI
                    3'h3: Operation = 4'd12;                     // SLTIU
                    3'h4: Operation = 4'd03;                     // XORI
                    3'h5: Operation = Funct7[5] ? 4'd08 : 4'd07; // Diferencia SRAI (1) e SRLI (0)
                    3'h6: Operation = 4'd04;                     // ORI
                    3'h7: Operation = 4'd05;                     // ANDI
                    default: Operation = 4'd01;
                endcase
            end

            default: Operation = 4'd01;
        endcase
    end

endmodule