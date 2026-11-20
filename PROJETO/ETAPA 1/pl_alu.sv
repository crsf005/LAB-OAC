// =============================================================================
// pl_alu.sv
// Unidade Lógica e Aritmética (ALU) -- RV32I Pipelined (Estágio EX)
//
// Executa operações aritméticas, lógicas, de deslocamento e comparação sobre
// dois operandos de 32 bits (SrcA e SrcB) conforme o código Operation.
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
            // Operações Aritméticas (com sinal em complemento de dois)
            4'd01:  ALUResult = $signed(SrcA) + $signed(SrcB);        // [Base] ADD / endereço (LW, SW)
            4'd02:  ALUResult = $signed(SrcA) - $signed(SrcB);        // [Base] SUB / igualdade (BEQ)

            // Operações Lógicas bit a bit
            4'd03:  ALUResult = SrcA ^ SrcB;                          // [Etapa 01] XOR (OU-exclusivo)
            4'd04:  ALUResult = SrcA | SrcB;                          // [Base] OR
            4'd05:  ALUResult = SrcA & SrcB;                          // [Base] AND

            // Operações de Deslocamento (usa apenas SrcB[4:0]: 0 a 31 bits)
            4'd06:  ALUResult = SrcA << SrcB[4:0];                    // [Etapa 01] SLL (shift lógico à esquerda)
            4'd07:  ALUResult = SrcA >> SrcB[4:0];                    // [Etapa 01] SRL (shift lógico à direita, preenche com 0)
            4'd08:  ALUResult = $signed(SrcA) >>> SrcB[4:0];          // [Etapa 01] SRA (shift aritmético à direita, preserva sinal)

            // Operações de Comparação (retorna 32'd1 se verdadeiro, 32'd0 caso contrário)
            4'd11:  ALUResult = 32'($signed(SrcA) < $signed(SrcB));   // [Base] SLT (menor que com sinal)
            4'd12:  ALUResult = 32'(SrcA < SrcB);                     // [Etapa 01] SLTU (menor que sem sinal / magnitude)

            default: ALUResult = 32'b0;                               
        endcase
    end

    // Flag Zero utilizada pela unidade de desvio condicional (BEQ) no estágio EX
    assign Zero = (ALUResult == 32'b0);

endmodule
