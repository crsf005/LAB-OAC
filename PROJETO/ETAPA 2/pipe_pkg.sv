package pl_pipe_pkg;

    typedef struct packed {
        logic [31:0] pc;
        logic [31:0] instr;
    } if_id_t;

    typedef struct packed {
        logic        alu_src;
        logic [1:0]  alu_src_a;
        logic        mem_to_reg;
        logic        reg_write;
        logic        mem_read;
        logic        mem_write;
        logic [1:0]  alu_op;
        logic        branch;
        logic [31:0] pc;
        logic [31:0] rd1;
        logic [31:0] rd2;
        logic [4:0]  rs1;
        logic [4:0]  rs2;
        logic [4:0]  rd;
        logic [31:0] imm_ext;
        logic [2:0]  funct3;
        logic [6:0]  funct7;
    } id_ex_t;

    typedef struct packed {
        logic        mem_to_reg;
        logic        reg_write;
        logic        mem_read;
        logic        mem_write;
        logic [31:0] alu_result;
        logic [31:0] write_data;
        logic [4:0]  rd;
        logic [2:0]  funct3;
    } ex_mem_t;

    typedef struct packed {
        logic        mem_to_reg;
        logic        reg_write;
        logic [31:0] alu_result;
        logic [31:0] read_data;
        logic [4:0]  rd;
    } mem_wb_t;

endpackage