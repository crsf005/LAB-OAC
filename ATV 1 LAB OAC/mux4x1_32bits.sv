module mux_4x1_32bits (
    input  logic [3:0][31:0] d,
    input  logic [1:0]       sel,
    output logic [31:0]      y
);

    wire sel0_n, sel1_n;
    wire [31:0] and0, and1, and2, and3;
    wire [31:0] s0_n_vec, s1_n_vec, s0_vec, s1_vec;

    not u_not0 (sel0_n, sel[0]);
    not u_not1 (sel1_n, sel[1]);

    assign s0_n_vec = {32{sel0_n}};
    assign s1_n_vec = {32{sel1_n}};
    assign s0_vec   = {32{sel[0]}};
    assign s1_vec   = {32{sel[1]}};

    and u_and0 [31:0] (and0, d[0], s1_n_vec, s0_n_vec);
    and u_and1 [31:0] (and1, d[1], s1_n_vec, s0_vec);
    and u_and2 [31:0] (and2, d[2], s1_vec,   s0_n_vec);
    and u_and3 [31:0] (and3, d[3], s1_vec,   s0_vec);

    or u_or0 [31:0] (y, and0, and1, and2, and3);

endmodule