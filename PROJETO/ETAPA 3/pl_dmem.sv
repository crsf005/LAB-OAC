`timescale 1ns / 1ps

module pl_dmem (
    input  logic        clk,
    input  logic        MemWrite,
    input  logic [2:0]  Funct3,      // [Etapa 03] Nova entrada para selecionar tamanho e extensao de sinal (byte/half/word)
    input  logic [1:0]  byte_offset, // [Etapa 03] Nova entrada (alu_result[1:0]) para alinhar byte ou halfword na palavra
    input  logic [7:0]  addr,
    input  logic [31:0] WriteData,
    output logic [31:0] ReadData
);

    (* ram_init_file = "data.mif" *) logic [31:0] ram [0:255];

    // synthesis translate_off
    initial begin
        for (int i = 0; i < 256; i++) ram[i] = 32'h00000000;
        $readmemh("data.hex", ram);
    end
    // synthesis translate_on

    logic [31:0] raw_word;
    assign raw_word = ram[addr];

    // [Etapa 03] Logica read-modify-write combinacional para suportar escritas parciais SB e SH alem de SW
    logic [31:0] new_word;

    always_comb begin
        new_word = WriteData;
        case (Funct3[1:0])
            2'b00: begin // [Etapa 03] SB: substitui apenas o byte selecionado por byte_offset
                case (byte_offset)
                    2'b00: new_word = {raw_word[31:8],  WriteData[7:0]};
                    2'b01: new_word = {raw_word[31:16], WriteData[7:0], raw_word[7:0]};
                    2'b10: new_word = {raw_word[31:24], WriteData[7:0], raw_word[15:0]};
                    2'b11: new_word = {WriteData[7:0],  raw_word[23:0]};
                endcase
            end
            2'b01: begin // [Etapa 03] SH: substitui a meia-palavra inferior ou superior conforme byte_offset[1]
                if (byte_offset[1])
                    new_word = {WriteData[15:0], raw_word[15:0]};
                else
                    new_word = {raw_word[31:16], WriteData[15:0]};
            end
            default: new_word = WriteData; // SW
        endcase
    end

    // Usa always @(posedge clk) para permitir a inicializacao via $readmemh no bloco initial
    always @(posedge clk) begin
        if (MemWrite) ram[addr] <= new_word; // [Etapa 03] Grava a palavra montada (new_word) em vez de WriteData direto
    end

    // [Etapa 03] Selecao de byte e halfword para leituras sub-word (LB, LH, LBU, LHU)
    logic [7:0]  selected_byte;
    logic [15:0] selected_half;

    always_comb begin
        case (byte_offset)
            2'b00: selected_byte = raw_word[7:0];
            2'b01: selected_byte = raw_word[15:8];
            2'b10: selected_byte = raw_word[23:16];
            2'b11: selected_byte = raw_word[31:24];
        endcase
    end

    assign selected_half = byte_offset[1] ? raw_word[31:16] : raw_word[15:0];

    // [Etapa 03] Multiplexador de saida com extensao de sinal (LB/LH) ou extensao de zeros (LBU/LHU)
    always_comb begin
        case (Funct3)
            3'b000:  ReadData = {{24{selected_byte[7]}},  selected_byte}; // [Etapa 03] LB
            3'b001:  ReadData = {{16{selected_half[15]}}, selected_half}; // [Etapa 03] LH
            3'b010:  ReadData = raw_word;                                 // LW
            3'b100:  ReadData = {24'b0, selected_byte};                   // [Etapa 03] LBU
            3'b101:  ReadData = {16'b0, selected_half};                   // [Etapa 03] LHU
            default: ReadData = raw_word;
        endcase
    end

endmodule
