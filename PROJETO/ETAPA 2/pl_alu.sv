// =============================================================================
// pl_alu.sv
// Unidade Lógica e Aritmética (ALU) -- RV32I Pipelined (Estágio EX)
//
// Executa operações aritméticas, lógicas, de deslocamento e comparação de 32 bits.
// [Etapa 02] Nenhuma alteração de hardware: reutiliza as operações da Etapa 01
//            para atender também às instruções Tipo-I (OP-IMM), LUI e AUIPC.
// =============================================================================

`timescale 1ns / 1ps

module pl_alu (
    input  logic [31:0] SrcA,      
    input  logic [31:0] SrcB,      
    input  logic [3:0]  Operation, 
    output logic [31:0] ALUResult, 
    output logic        Zero       
);

    always_comb begin
        case (Operation)
            4'd01:  ALUResult = $signed(SrcA) + $signed(SrcB);
            4'd02:  ALUResult = $signed(SrcA) - $signed(SrcB);
            4'd03:  ALUResult = SrcA ^ SrcB;
            4'd04:  ALUResult = SrcA | SrcB;
            4'd05:  ALUResult = SrcA & SrcB;
            4'd06:  ALUResult = SrcA << SrcB[4:0];
            4'd07:  ALUResult = SrcA >> SrcB[4:0];
            4'd08:  ALUResult = $signed(SrcA) >>> SrcB[4:0];
            4'd11:  ALUResult = 32'($signed(SrcA) < $signed(SrcB));
            4'd12:  ALUResult = 32'(SrcA < SrcB);
            default: ALUResult = 32'b0;
        endcase
    end

    assign Zero = (ALUResult == 32'b0);

endmodule