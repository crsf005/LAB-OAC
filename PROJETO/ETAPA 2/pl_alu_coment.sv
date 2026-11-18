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
            4'd01:  ALUResult = $signed(SrcA) + $signed(SrcB);        // ADD / ADDI / Loads / Stores
            4'd02:  ALUResult = $signed(SrcA) - $signed(SrcB);        // SUB / Branch (BEQ)
            4'd03:  ALUResult = SrcA ^ SrcB;                          // XOR / XORI
            4'd04:  ALUResult = SrcA | SrcB;                          // OR / ORI
            4'd05:  ALUResult = SrcA & SrcB;                          // AND / ANDI
            4'd06:  ALUResult = SrcA << SrcB[4:0];                    // SLL / SLLI 
            4'd07:  ALUResult = SrcA >> SrcB[4:0];                    // SRL / SRLI 
            4'd08:  ALUResult = $signed(SrcA) >>> SrcB[4:0];          // SRA / SRAI 
            4'd11:  ALUResult = 32'($signed(SrcA) < $signed(SrcB));   // SLT / SLTI 
            4'd12:  ALUResult = 32'(SrcA < SrcB);                     // SLTU / SLTIU 
            default: ALUResult = 32'b0;
        endcase
    end

    
    assign Zero = (ALUResult == 32'b0);

endmodule