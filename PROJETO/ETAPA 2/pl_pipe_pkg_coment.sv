package pl_pipe_pkg;

    // Estruturas (structs) que consolidam os fios de comunicação que fluem
    // nos registradores entre cada estágio.

    // Registrador entre Inst-Fetch e Inst-Decode
    typedef struct packed {
        logic [31:0] pc;
        logic [31:0] instr; // Instrução lida bruta
    } if_id_t;

    // Registrador entre Inst-Decode e Execution
    typedef struct packed {
        // Sinais de controle de propagação
        logic        alu_src;
        logic [1:0]  alu_src_a; // Controle de origem A 
        logic        mem_to_reg;
        logic        reg_write;
        logic        mem_read;
        logic        mem_write;
        logic [1:0]  alu_op;
        logic        branch;
        // Caminho de dados (Data)
        logic [31:0] pc;
        logic [31:0] rd1;       // Valor contido em rs1
        logic [31:0] rd2;       // Valor contido em rs2
        logic [4:0]  rs1;       // Endereço rs1 (levado para resolver Forwarding)
        logic [4:0]  rs2;       // Endereço rs2 (levado para resolver Forwarding)
        logic [4:0]  rd;        // Endereço do reg destino
        logic [31:0] imm_ext;   // Imediato já com extensão de sinal processada
        logic [2:0]  funct3;
        logic [6:0]  funct7;
    } id_ex_t;

    // Registrador entre Execution e Memory
    typedef struct packed {
        logic        mem_to_reg;
        logic        reg_write;
        logic        mem_read;
        logic        mem_write;
        logic [31:0] alu_result; // Serve como valor matemático ou Endereço de Memória
        logic [31:0] write_data; // O dado bruto (rd2) se for uma operação Store
        logic [4:0]  rd;
        logic [2:0]  funct3;
    } ex_mem_t;

    // Registrador entre Memory e Write-Back
    typedef struct packed {
        logic        mem_to_reg;
        logic        reg_write;
        logic [31:0] alu_result;
        logic [31:0] read_data;  // Valor extraído no LW
        logic [4:0]  rd;         // Destino de onde salvar no RegFile
    } mem_wb_t;

endpackage