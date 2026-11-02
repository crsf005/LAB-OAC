`timescale 1ns / 1ps

import pl_pipe_pkg::*;

module pl_datapath (
    input  logic        clk,
    input  logic        rst_n,

    input  logic        ALUSrc,
    input  logic [1:0]  ALUSrcA,
    input  logic        MemtoReg,
    input  logic        RegWrite,
    input  logic        MemRead,
    input  logic        MemWrite,
    input  logic        Branch,
    input  logic [1:0]  ALUOp,

    input  logic [3:0]  ALU_CC,

    output logic [6:0]  Opcode,
    output logic [2:0]  Funct3_EX,
    output logic [6:0]  Funct7_EX,
    output logic [1:0]  ALUOp_EX,

    output logic [31:0] PC,

    input  logic [17:0] SW,
    input  logic [3:0]  KEY,
    output logic [17:0] LEDR,
    output logic [8:0]  LEDG,
    output logic        UART_TXD,
    input  logic        UART_RXD,

    output logic        wb_reg_write,
    output logic [4:0]  wb_reg_dst,
    output logic [31:0] wb_reg_data,
    output logic        mem_wr_en,
    output logic [7:0]  mem_wr_addr,
    output logic [31:0] mem_wr_data
);

    logic [31:0] pc_reg, pc_plus4;

    if_id_t  if_id;
    id_ex_t  id_ex;
    ex_mem_t ex_mem;
    mem_wb_t mem_wb;

    logic        stall;
    logic        pc_src;
    logic [31:0] branch_target;

    logic [31:0] rd1, rd2, imm_ext;

    logic [1:0]  fwd_a, fwd_b;
    logic [31:0] fwd_srca, fwd_srcb, alu_srca, alu_srcb;
    logic [31:0] alu_result;
    logic        zero;

    logic [31:0] wb_data;

    logic        mmio_sel;
    logic [31:0] dmem_rd, mmio_rd, mem_read_data;

    logic [31:0] instr_if;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)      pc_reg <= 32'b0;
        else if (pc_src) pc_reg <= branch_target;
        else if (!stall) pc_reg <= pc_plus4;
    end

    assign PC       = pc_reg;
    assign pc_plus4 = pc_reg + 32'd4;

    pl_imem imem (
        .addr  (pc_reg[9:2]),
        .instr (instr_if)
    );

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            if_id.pc    <= 32'b0;
            if_id.instr <= 32'b0;
        end else if (pc_src) begin
            if_id.pc    <= 32'b0;
            if_id.instr <= 32'b0;
        end else if (!stall) begin
            if_id.pc    <= pc_reg;
            if_id.instr <= instr_if;
        end
    end

    assign Opcode = if_id.instr[6:0];

    pl_hazard hazard (
        .if_id_rs1      (if_id.instr[19:15]),
        .if_id_rs2      (if_id.instr[24:20]),
        .id_ex_rd       (id_ex.rd),
        .id_ex_mem_read (id_ex.mem_read),
        .stall          (stall)
    );

    assign wb_data = mem_wb.mem_to_reg ? mem_wb.read_data : mem_wb.alu_result;

    pl_regfile regfile (
        .clk       (clk),
        .RegWrite  (mem_wb.reg_write),
        .rs1       (if_id.instr[19:15]),
        .rs2       (if_id.instr[24:20]),
        .rd        (mem_wb.rd),
        .WriteData (wb_data),
        .ReadData1 (rd1),
        .ReadData2 (rd2)
    );

    pl_sign_ext sign_ext (
        .Instr  (if_id.instr),
        .ImmExt (imm_ext)
    );

    assign wb_reg_write = mem_wb.reg_write;
    assign wb_reg_dst   = mem_wb.rd;
    assign wb_reg_data  = wb_data;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            id_ex.alu_src   <= 1'b0;
            id_ex.alu_src_a <= 2'b00;
            id_ex.mem_to_reg<= 1'b0;
            id_ex.reg_write <= 1'b0;
            id_ex.mem_read  <= 1'b0;
            id_ex.mem_write <= 1'b0;
            id_ex.alu_op    <= 2'b00;
            id_ex.branch    <= 1'b0;
            id_ex.pc        <= 32'b0;
            id_ex.rd1       <= 32'b0;
            id_ex.rd2       <= 32'b0;
            id_ex.rs1       <= 5'b0;
            id_ex.rs2       <= 5'b0;
            id_ex.rd        <= 5'b0;
            id_ex.imm_ext   <= 32'b0;
            id_ex.funct3    <= 3'b0;
            id_ex.funct7    <= 7'b0;
        end else if (stall || pc_src) begin
            id_ex.alu_src   <= 1'b0;
            id_ex.alu_src_a <= 2'b00;
            id_ex.mem_to_reg<= 1'b0;
            id_ex.reg_write <= 1'b0;
            id_ex.mem_read  <= 1'b0;
            id_ex.mem_write <= 1'b0;
            id_ex.alu_op    <= 2'b00;
            id_ex.branch    <= 1'b0;
            id_ex.pc        <= 32'b0;
            id_ex.rd1       <= 32'b0;
            id_ex.rd2       <= 32'b0;
            id_ex.rs1       <= 5'b0;
            id_ex.rs2       <= 5'b0;
            id_ex.rd        <= 5'b0;
            id_ex.imm_ext   <= 32'b0;
            id_ex.funct3    <= 3'b0;
            id_ex.funct7    <= 7'b0;
        end else begin
            id_ex.alu_src   <= ALUSrc;
            id_ex.alu_src_a <= ALUSrcA;
            id_ex.mem_to_reg<= MemtoReg;
            id_ex.reg_write <= RegWrite;
            id_ex.mem_read  <= MemRead;
            id_ex.mem_write <= MemWrite;
            id_ex.alu_op    <= ALUOp;
            id_ex.branch    <= Branch;
            id_ex.pc        <= if_id.pc;
            id_ex.rd1       <= rd1;
            id_ex.rd2       <= rd2;
            id_ex.rs1       <= if_id.instr[19:15];
            id_ex.rs2       <= if_id.instr[24:20];
            id_ex.rd        <= if_id.instr[11:7];
            id_ex.imm_ext   <= imm_ext;
            id_ex.funct3    <= if_id.instr[14:12];
            id_ex.funct7    <= if_id.instr[31:25];
        end
    end

    assign Funct3_EX = id_ex.funct3;
    assign Funct7_EX = id_ex.funct7;
    assign ALUOp_EX  = id_ex.alu_op;

    pl_forward forward (
        .id_ex_rs1        (id_ex.rs1),
        .id_ex_rs2        (id_ex.rs2),
        .ex_mem_rd        (ex_mem.rd),
        .mem_wb_rd        (mem_wb.rd),
        .ex_mem_reg_write (ex_mem.reg_write),
        .mem_wb_reg_write (mem_wb.reg_write),
        .forward_a        (fwd_a),
        .forward_b        (fwd_b)
    );

    always_comb begin
        case (fwd_a)
            2'b10:   fwd_srca = ex_mem.alu_result;
            2'b01:   fwd_srca = wb_data;
            default: fwd_srca = id_ex.rd1;
        endcase
    end

    always_comb begin
        case (fwd_b)
            2'b10:   fwd_srcb = ex_mem.alu_result;
            2'b01:   fwd_srcb = wb_data;
            default: fwd_srcb = id_ex.rd2;
        endcase
    end

    always_comb begin
        case (id_ex.alu_src_a)
            2'b01:   alu_srca = id_ex.pc;
            2'b10:   alu_srca = 32'b0;
            default: alu_srca = fwd_srca;
        endcase
    end

    assign alu_srcb = id_ex.alu_src ? id_ex.imm_ext : fwd_srcb;

    pl_alu alu (
        .SrcA      (alu_srca),
        .SrcB      (alu_srcb),
        .Operation (ALU_CC),
        .ALUResult (alu_result),
        .Zero      (zero)
    );

    assign branch_target = id_ex.pc + id_ex.imm_ext;
    assign pc_src        = id_ex.branch && zero;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ex_mem.mem_to_reg  <= 1'b0;
            ex_mem.reg_write   <= 1'b0;
            ex_mem.mem_read    <= 1'b0;
            ex_mem.mem_write   <= 1'b0;
            ex_mem.alu_result  <= 32'b0;
            ex_mem.write_data  <= 32'b0;
            ex_mem.rd          <= 5'b0;
            ex_mem.funct3      <= 3'b0;
        end else begin
            ex_mem.mem_to_reg  <= id_ex.mem_to_reg;
            ex_mem.reg_write   <= id_ex.reg_write;
            ex_mem.mem_read    <= id_ex.mem_read;
            ex_mem.mem_write   <= id_ex.mem_write;
            ex_mem.alu_result  <= alu_result;
            ex_mem.write_data  <= fwd_srcb;
            ex_mem.rd          <= id_ex.rd;
            ex_mem.funct3      <= id_ex.funct3;
        end
    end

    assign mmio_sel = ex_mem.alu_result[10];

    pl_dmem dmem (
        .clk       (clk),
        .MemWrite  (ex_mem.mem_write & ~mmio_sel),
        .addr      (ex_mem.alu_result[9:2]),
        .WriteData (ex_mem.write_data),
        .ReadData  (dmem_rd)
    );

    pl_mmio mmio (
        .clk       (clk),
        .rst_n     (rst_n),
        .MemWrite  (ex_mem.mem_write &  mmio_sel),
        .MemRead   (ex_mem.mem_read  &  mmio_sel),
        .addr      (ex_mem.alu_result[4:2]),
        .WriteData (ex_mem.write_data),
        .SW        (SW),
        .KEY       (KEY),
        .ReadData  (mmio_rd),
        .LEDR      (LEDR),
        .LEDG      (LEDG),
        .UART_TXD  (UART_TXD),
        .UART_RXD  (UART_RXD)
    );

    assign mem_read_data = mmio_sel ? mmio_rd : dmem_rd;

    assign mem_wr_en   = ex_mem.mem_write & ~mmio_sel;
    assign mem_wr_addr = ex_mem.alu_result[9:2];
    assign mem_wr_data = ex_mem.write_data;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_wb.mem_to_reg <= 1'b0;
            mem_wb.reg_write  <= 1'b0;
            mem_wb.alu_result <= 32'b0;
            mem_wb.read_data  <= 32'b0;
            mem_wb.rd         <= 5'b0;
        end else begin
            mem_wb.mem_to_reg <= ex_mem.mem_to_reg;
            mem_wb.reg_write  <= ex_mem.reg_write;
            mem_wb.alu_result <= ex_mem.alu_result;
            mem_wb.read_data  <= mem_read_data;
            mem_wb.rd         <= ex_mem.rd;
        end
    end

endmodule