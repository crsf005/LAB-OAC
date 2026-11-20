// =============================================================================
// pl_sign_ext.sv
// Gerador de Imediatos e Extensor de Sinal -- RV32I Pipelined (Estágio ID)
//
// Extrai os bits do imediato conforme o formato da instrução e estende para 32 bits.
// =============================================================================

`timescale 1ns / 1ps

module pl_sign_ext (
    input  logic [31:0] Instr,
    output logic [31:0] ImmExt
);

    localparam LOAD   = 7'b0000011;
    localparam STORE  = 7'b0100011;
    localparam BRANCH = 7'b1100011;
    localparam OP_IMM = 7'b0010011; // [Etapa 02] Novo parâmetro para Tipo-I aritmético/lógico
    localparam LUI    = 7'b0110111; // [Etapa 02] Novo parâmetro para Tipo-U (LUI)
    localparam AUIPC  = 7'b0010111; // [Etapa 02] Novo parâmetro para Tipo-U (AUIPC)

    always_comb begin
        case (Instr[6:0])
            // [Etapa 02] OP_IMM agrupado ao formato Tipo-I de 12 bits com extensão de sinal
            LOAD, OP_IMM: ImmExt = {{20{Instr[31]}}, Instr[31:20]};

            STORE:        ImmExt = {{20{Instr[31]}}, Instr[31:25], Instr[11:7]};

            BRANCH:       ImmExt = {{19{Instr[31]}}, Instr[31], Instr[7],
                                    Instr[30:25], Instr[11:8], 1'b0};

            // [Etapa 02] Novo formato Tipo-U: posiciona 20 bits superiores e preenche LSBs com zero
            LUI, AUIPC:   ImmExt = {Instr[31:12], 12'b0};

            default:      ImmExt = 32'b0;
        endcase
    end

endmodule