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

    always_comb begin
        case (Instr[6:0])
            LOAD, OP_IMM: ImmExt = {{20{Instr[31]}}, Instr[31:20]};

            STORE:        ImmExt = {{20{Instr[31]}}, Instr[31:25], Instr[11:7]};

            BRANCH:       ImmExt = {{19{Instr[31]}}, Instr[31], Instr[7],
                                    Instr[30:25], Instr[11:8], 1'b0};

            LUI, AUIPC:   ImmExt = {Instr[31:12], 12'b0};

            default:      ImmExt = 32'b0;
        endcase
    end

endmodule