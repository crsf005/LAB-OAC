`timescale 1ns / 1ps

// Unidade que extrai os fragmentos do campo de imediato da instrução 
// e estende o sinal (bit 31) para transformar o valor em 32 bits puros,
module pl_sign_ext (
    input  logic [31:0] Instr,
    output logic [31:0] ImmExt
);

    localparam LOAD   = 7'b0000011;
    localparam STORE  = 7'b0100011;
    localparam BRANCH = 7'b1100011;
    localparam OP_IMM = 7'b0010011;
    localparam LUI    = 7'b0110111;
    localparam AUIPC  = 7'b0010111;

    always_comb begin
        case (Instr[6:0])
            // Instruções Tipo-I: O imediato de 12 bits está do bit 20 ao 31
            LOAD, OP_IMM: ImmExt = {{20{Instr[31]}}, Instr[31:20]};

            // Instruções Tipo-S: O imediato é fragmentado entre [31:25] e [11:7]
            STORE:        ImmExt = {{20{Instr[31]}}, Instr[31:25], Instr[11:7]};

            // Instruções Tipo-B: Fragmentado e fora de ordem para facilitar hardware. 
            // Multiplicado por 2 implicitamente (termina em bit '0').
            BRANCH:       ImmExt = {{19{Instr[31]}}, Instr[31], Instr[7],
                                    Instr[30:25], Instr[11:8], 1'b0};

            // Instruções Tipo-U: O imediato está nos 20 bits superiores.
            // Os 12 bits menos significativos são zerados (deslocamento para a esquerda de imediato longo).
            LUI, AUIPC:   ImmExt = {Instr[31:12], 12'b0};

            default:      ImmExt = 32'b0;
        endcase
    end

endmodule