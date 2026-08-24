`timescale 1ns/1ps

module tb_mux_4x1;  
    logic [5:0] count;  
    logic y_out;   

    mux_4x1 dut (
        .d(count[5:2]),
        .sel(count[1:0]),
        .y(y_out)
    );   

    initial begin     
        $monitor($time, " d = %b | sel = %b | y = %b", count[5:2], count[1:0], y_out);    
        for(count = 0; count != 6'b111111; count++) #10;          
        #10 $stop;  
    end
endmodule: tb_mux_4x1