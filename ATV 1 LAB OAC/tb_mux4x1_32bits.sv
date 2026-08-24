`timescale 1ns/1ps

module tb_mux_4x1_32bits;  
    logic [3:0][31:0] d_in;
    logic [1:0]       sel_in;
    logic [31:0]      y_out;   

    mux_4x1_32bits dut (
        .d(d_in),
        .sel(sel_in),
        .y(y_out)
    );   

    int i;

    initial begin     
        d_in[0] = 32'h11111111; 
        d_in[1] = 32'h22222222; 
        d_in[2] = 32'h33333333; 
        d_in[3] = 32'h44444444; 

        $monitor($time, " d0=%h d1=%h d2=%h d3=%h | sel = %b | y = %h", 
                 d_in[0], d_in[1], d_in[2], d_in[3], sel_in, y_out);    
        
        for (i = 0; i < 4; i++) begin
            sel_in = i[1:0];
            #10;
        end
        
        #10 $stop;  
    end
endmodule: tb_mux_4x1_32bits