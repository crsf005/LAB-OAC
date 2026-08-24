module mux_4x1 (
    input  logic [3:0] d,    
    input  logic [1:0] sel,  
    output logic       y     
);

    logic sel0_n, sel1_n;

    logic and0, and1, and2, and3;


    not u_not0 (sel0_n, sel[0]);
    not u_not1 (sel1_n, sel[1]);

    
    and u_and0 (and0, d[0], sel1_n, sel0_n);
    and u_and1 (and1, d[1], sel1_n, sel[0]);
    and u_and2 (and2, d[2], sel[1],  sel0_n);
    and u_and3 (and3, d[3], sel[1],  sel[0]);

    or u_or0 (y, and0, and1, and2, and3);

endmodule
