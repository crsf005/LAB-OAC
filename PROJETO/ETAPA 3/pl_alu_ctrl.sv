`timescale 1ns / 1ps

module pl_alu_ctrl (
    input  logic [1:0] ALUOp,
    input  logic [6:0] Funct7,
    input  logic [2:0] Funct3,
    output logic [3:0] Operation
);

    always_comb begin
        case (ALUOp)
            2'b00: Operation = 4'd01;

            // [Etapa 03] Expande ALUOp = 2'b01 (antes fixo em SUB para BEQ) para decodificar todos os desvios B-type via Funct3
            2'b01: begin
                case (Funct3)
                    3'h0: Operation = 4'd02; // [Etapa 03] BEQ  -> SUB 
                    3'h1: Operation = 4'd02; // [Etapa 03] BNE  -> SUB 
                    3'h4: Operation = 4'd11; // [Etapa 03] BLT  -> SLT 
                    3'h5: Operation = 4'd11; // [Etapa 03] BGE  -> SLT 
                    3'h6: Operation = 4'd12; // [Etapa 03] BLTU -> SLTU 
                    3'h7: Operation = 4'd12; // [Etapa 03] BGEU -> SLTU 
                    default: Operation = 4'd02;
                endcase
            end

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

            2'b11: begin
                case (Funct3)
                    3'h0: Operation = 4'd01;
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

            default: Operation = 4'd01;
        endcase
    end

endmodule