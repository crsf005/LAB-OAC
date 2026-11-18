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
            4'd01:  ALUResult = $signed(SrcA) + $signed(SrcB);        // ADD / ADDI / cálculo de endereço (LW, SW)
            4'd02:  ALUResult = $signed(SrcA) - $signed(SrcB);        // SUB / comparação de igualdade (BEQ, BNE)

            // Operações Lógicas bit a bit
            4'd03:  ALUResult = SrcA ^ SrcB;                          // XOR / XORI
            4'd04:  ALUResult = SrcA | SrcB;                          // OR / ORI
            4'd05:  ALUResult = SrcA & SrcB;                          // AND / ANDI

            // Operações de Deslocamento (usa apenas os 5 bits inferiores de SrcB: 0 a 31 bits)
            4'd06:  ALUResult = SrcA << SrcB[4:0];                    // SLL / SLLI (deslocamento lógico à esquerda)
            4'd07:  ALUResult = SrcA >> SrcB[4:0];                    // SRL / SRLI (deslocamento lógico à direita, preenche com 0)
            4'd08:  ALUResult = $signed(SrcA) >>> SrcB[4:0];          // SRA / SRAI (deslocamento aritmético à direita, preserva bit de sinal)

            // Operações de Comparação (retorna 32'd1 se verdadeiro, 32'd0 caso contrário)
            4'd11:  ALUResult = 32'($signed(SrcA) < $signed(SrcB));   // SLT / SLTI (menor que com sinal)
            4'd12:  ALUResult = 32'(SrcA < SrcB);                     // SLTU / SLTIU (menor que sem sinal / magnitude)

            default: ALUResult = 32'b0;                               
        endcase
    end

    // Flag Zero utilizada pela unidade de desvio condicional no estágio EX
    assign Zero = (ALUResult == 32'b0);

endmodule
