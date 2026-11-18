`timescale 1ns / 1ps

import pl_pipe_pkg::*;

// Contém a lógica sequencial e combinacional
// dividida em 5 estágios: IF (Fetch), ID (Decode), EX (Exec), MEM (Memory), WB (Writeback).
module pl_datapath (
    input  logic        clk,
    input  logic        rst_n,

    // Controles que entram (do estágio ID)
    input  logic        ALUSrc,
    input  logic [1:0]  ALUSrcA,
    input  logic        MemtoReg,
    input  logic        RegWrite,
    input  logic        MemRead,
    input  logic        MemWrite,
    input  logic        Branch,
    input  logic [1:0]  ALUOp,

    // Sinal processado que entra para controlar a ALU
    input  logic [3:0]  ALU_CC,

    // Realimentação para as unidades de controle no nível pl_cpu
    output logic [6:0]  Opcode,
    output logic [2:0]  Funct3_EX,
    output logic [6:0]  Funct7_EX,
    output logic [1:0]  ALUOp_EX,

    output logic [31:0] PC,

    // Entradas e saídas de MMIO (Memory Mapped I/O)
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

    // Registradores do Pipeline (que separam os estágios)
    if_id_t  if_id;
    id_ex_t  id_ex;
    ex_mem_t ex_mem;
    mem_wb_t mem_wb;

    // Sinais de controle de riscos (hazards)
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


    // 1. ESTÁGIO IF (Instruction Fetch) - Busca de Instrução
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)      pc_reg <= 32'b0;
        else if (pc_src) pc_reg <= branch_target; // Se branch tomado, atualiza PC
        else if (!stall) pc_reg <= pc_plus4;      // Se não há stall (bolha), PC = PC + 4
    end

    assign PC       = pc_reg;
    assign pc_plus4 = pc_reg + 32'd4;

    pl_imem imem (
        .addr  (pc_reg[9:2]), // Busca instrução na memória baseada no PC alinhado
        .instr (instr_if)
    );

    // REGISTRADOR IF/ID
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n || pc_src) begin // Flush no branch tomado zera o registrador
            if_id.pc    <= 32'b0;
            if_id.instr <= 32'b0;
        end else if (!stall) begin  // Apenas flui dados se não houver stall (load-use hazard)
            if_id.pc    <= pc_reg;
            if_id.instr <= instr_if;
        end
    end

    // 2. ESTÁGIO ID (Instruction Decode) - Decodificação e Leitura
    assign Opcode = if_id.instr[6:0]; // Extrai o Opcode para a Control Unit

    // Unidade de Hazard: detecta conflito "load-use" 
    pl_hazard hazard (
        .if_id_rs1      (if_id.instr[19:15]),
        .if_id_rs2      (if_id.instr[24:20]),
        .id_ex_rd       (id_ex.rd),
        .id_ex_mem_read (id_ex.mem_read),
        .stall          (stall)
    );

    // Multiplexador da fase de WB: decide se escreve resultado da ALU ou da memória
    assign wb_data = mem_wb.mem_to_reg ? mem_wb.read_data : mem_wb.alu_result;

    // Banco de Registradores
    pl_regfile regfile (
        .clk       (clk),
        .RegWrite  (mem_wb.reg_write),
        .rs1       (if_id.instr[19:15]), // Lê Source 1
        .rs2       (if_id.instr[24:20]), // Lê Source 2
        .rd        (mem_wb.rd),          // Endereço de gravação (vindo lá do final do pipeline)
        .WriteData (wb_data),            // Dado vindo do final do pipeline
        .ReadData1 (rd1),
        .ReadData2 (rd2)
    );

    // Unidade de Extensão de Sinal
    pl_sign_ext sign_ext (
        .Instr  (if_id.instr),
        .ImmExt (imm_ext)
    );

    assign wb_reg_write = mem_wb.reg_write;
    assign wb_reg_dst   = mem_wb.rd;
    assign wb_reg_data  = wb_data;

    // REGISTRADOR ID/EX
    always_ff @(posedge clk or negedge rst_n) begin
        // Zera os sinais de controle caso reset, bolha (stall) ou flush (pc_src)
        if (!rst_n || stall || pc_src) begin
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
            // Passa os controles e os dados para frente
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

    // 3. ESTÁGIO EX (Execution) - ALU, Forwarding e Branch
    assign Funct3_EX = id_ex.funct3;
    assign Funct7_EX = id_ex.funct7;
    assign ALUOp_EX  = id_ex.alu_op;

    // Unidade de Forwarding: resolve dependências de dados lendo valores 
    // gerados nos estágios MEM ou WB que ainda não estão no RegFile
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

    // Resolve qual valor usar para SrcA dependendo do forwarding
    always_comb begin
        case (fwd_a)
            2'b10:   fwd_srca = ex_mem.alu_result; // Valor inicial do estágio MEM
            2'b01:   fwd_srca = wb_data;           // Valor final do estágio WB
            default: fwd_srca = id_ex.rd1;         // Valor original lido no ID
        endcase
    end

    // Resolve qual valor usar para o registrador base SrcB
    always_comb begin
        case (fwd_b)
            2'b10:   fwd_srcb = ex_mem.alu_result;
            2'b01:   fwd_srcb = wb_data;
            default: fwd_srcb = id_ex.rd2;
        endcase
    end

    // Mux da entrada A definitiva da ALU (trata os casos especiais LUI / AUIPC)
    always_comb begin
        case (id_ex.alu_src_a)
            2'b01:   alu_srca = id_ex.pc; // Usa o PC (AUIPC)
            2'b10:   alu_srca = 32'b0;    // Força 0 (LUI)
            default: alu_srca = fwd_srca; // Usa o registrador
        endcase
    end

    // Mux da entrada B definitiva: imediato ou registrador
    assign alu_srcb = id_ex.alu_src ? id_ex.imm_ext : fwd_srcb;

    // ALU Principal
    pl_alu alu (
        .SrcA      (alu_srca),
        .SrcB      (alu_srcb),
        .Operation (ALU_CC),
        .ALUResult (alu_result),
        .Zero      (zero)
    );

    // Lógica de Branch: Calcula endereço destino e se o salto ocorre (condição verdadeira)
    assign branch_target = id_ex.pc + id_ex.imm_ext;
    assign pc_src        = id_ex.branch && zero;

    // REGISTRADOR EX/MEM
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
            // O controle remanescente passa adiante, assim como o endereço/dado para a memória
            ex_mem.mem_to_reg  <= id_ex.mem_to_reg;
            ex_mem.reg_write   <= id_ex.reg_write;
            ex_mem.mem_read    <= id_ex.mem_read;
            ex_mem.mem_write   <= id_ex.mem_write;
            ex_mem.alu_result  <= alu_result; // Serve como endereço na fase de memória
            ex_mem.write_data  <= fwd_srcb;   // Dado a ser escrito (caso seja store)
            ex_mem.rd          <= id_ex.rd;
            ex_mem.funct3      <= id_ex.funct3;
        end
    end

    // 4. ESTÁGIO MEM (Memory) - Acesso à Memória de Dados e I/O
    // Sinal que decide se o endereço aponta para memória normal ou periféricos I/O (MMIO)
    assign mmio_sel = ex_mem.alu_result[10];

    pl_dmem dmem (
        .clk       (clk),
        .MemWrite  (ex_mem.mem_write & ~mmio_sel), // Apenas escreve se não for MMIO
        .addr      (ex_mem.alu_result[9:2]),
        .WriteData (ex_mem.write_data),
        .ReadData  (dmem_rd)
    );

    pl_mmio mmio (
        .clk       (clk),
        .rst_n     (rst_n),
        .MemWrite  (ex_mem.mem_write &  mmio_sel), // Apenas atua se for endereço de periférico
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

    // Mux que seleciona de onde veio a leitura (Memória RAM ou Dispositivo)
    assign mem_read_data = mmio_sel ? mmio_rd : dmem_rd;

    assign mem_wr_en   = ex_mem.mem_write & ~mmio_sel;
    assign mem_wr_addr = ex_mem.alu_result[9:2];
    assign mem_wr_data = ex_mem.write_data;

    // REGISTRADOR MEM/WB
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
            mem_wb.read_data  <= mem_read_data; // Dado da memória (se houver load)
            mem_wb.rd         <= ex_mem.rd;     // Registrador destino final
        end
    end
    

endmodule