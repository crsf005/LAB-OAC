`timescale 1ns / 1ps

module pl_dmem (
    input  logic        clk,
    input  logic        MemWrite,
    input  logic [2:0]  Funct3,      
    input  logic [1:0]  byte_offset, 
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
   

    always_ff @(posedge clk) begin
        if (MemWrite) begin
            case (Funct3[1:0])
                2'b00: begin 
                    case (byte_offset)
                        2'b00: ram[addr][7:0]   <= WriteData[7:0];
                        2'b01: ram[addr][15:8]  <= WriteData[7:0];
                        2'b10: ram[addr][23:16] <= WriteData[7:0];
                        2'b11: ram[addr][31:24] <= WriteData[7:0];
                    endcase
                end
                2'b01: begin 
                    case (byte_offset[1])
                        1'b0: ram[addr][15:0]  <= WriteData[15:0];
                        1'b1: ram[addr][31:16] <= WriteData[15:0];
                    endcase
                end
                2'b10: begin 
                    ram[addr] <= WriteData;
                end
                default: ram[addr] <= WriteData;
            endcase
        end
    end

    
    logic [31:0] raw_word;
    logic [7:0]  selected_byte;
    logic [15:0] selected_half;

    assign raw_word = ram[addr];

    
    always_comb begin
        case (byte_offset)
            2'b00: selected_byte = raw_word[7:0];
            2'b01: selected_byte = raw_word[15:8];
            2'b10: selected_byte = raw_word[23:16];
            2'b11: selected_byte = raw_word[31:24];
        endcase
    end

    
    always_comb begin
        case (byte_offset[1])
            1'b0: selected_half = raw_word[15:0];
            1'b1: selected_half = raw_word[31:16];
        endcase
    end

    
    always_comb begin
        case (Funct3)
            3'b000: ReadData = {{24{selected_byte[7]}}, selected_byte}; 
            3'b001: ReadData = {{16{selected_half[15]}}, selected_half}; 
            3'b010: ReadData = raw_word;                                 
            3'b100: ReadData = {24'b0, selected_byte};                  
            3'b101: ReadData = {16'b0, selected_half};                  
            default: ReadData = raw_word;
        endcase
    end

endmodule
