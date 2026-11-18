`timescale 1ns / 1ps

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
    localparam JAL    = 7'b1101111; // [Etapa 03] Opcode de JAL
    localparam JALR   = 7'b1100111; // [Etapa 03] Opcode de JALR

    always_comb begin
        case (Instr[6:0])
            // [Etapa 03] JALR incluido no formato imediato Tipo-I de 12 bits com extensao de sinal
            LOAD, OP_IMM, JALR: ImmExt = {{20{Instr[31]}}, Instr[31:20]};

            STORE:              ImmExt = {{20{Instr[31]}}, Instr[31:25], Instr[11:7]};

            BRANCH:             ImmExt = {{19{Instr[31]}}, Instr[31], Instr[7],
                                          Instr[30:25], Instr[11:8], 1'b0};

            LUI, AUIPC:         ImmExt = {Instr[31:12], 12'b0};

            // [Etapa 03] Novo caso para imediato Tipo-J (JAL): reconstroi deslocamento de 20 bits + bit 0 em zero
            JAL:                ImmExt = {{11{Instr[31]}}, Instr[31], Instr[19:12],
                                          Instr[20], Instr[30:21], 1'b0};

            default:            ImmExt = 32'b0;
        endcase
    end

endmodule