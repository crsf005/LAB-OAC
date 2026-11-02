===============================================================================
  DOCUMENTAÇÃO DE ALTERAÇÕES E ADIÇÕES - PROJETO RISC-V RV32I (ETAPA 02)
===============================================================================

1. VISÃO GERAL DAS ADIÇÕES
-------------------------------------------------------------------------------
Nesta etapa, o processador em pipeline de 5 estágios foi expandido para suportar
instruções com operandos imediatos (Tipo-I) e de imediato superior (Tipo-U).

Instruções adicionadas nesta etapa:
  - Tipo-I (Aritmética, Lógica e Deslocamento com Imediatos):
      ADDI, ANDI, ORI, SLTI, SLLI, SRLI, SRAI
  - Tipo-U (Imediato Superior):
      LUI   (Load Upper Immediate)
      AUIPC (Add Upper Immediate to PC)


2. RESUMO DOS ARQUIVOS MODIFICADOS
-------------------------------------------------------------------------------

[1] pl_alu_ctrl.sv (Controle da ALU)
    - Adicionado suporte ao código ALUOp = 2'b11 (reservado para Tipo-I / OP-IMM).
    - Mapeamento de Funct3 idêntico ao Tipo-R para as instruções I-type.
    - Correção em ADDI (Funct3 = 3'h0): desconsidera Funct7[5] para garantir
      operação ADD (evitando que imediatos negativos forcem SUB).
    - Manutenção da verificação de Funct7[5] apenas em SRLI (0) vs SRAI (1).

[2] pl_sign_ext.sv (Gerador de Imediatos / Extensão de Sinal)
    - Adicionados novos opcodes localparam: OP_IMM (0010011), LUI (0110111) e
      AUIPC (0010111).
    - Tipo-I (OP_IMM): agrupado com LOAD para extrair Instr[31:20] e estender
      o bit de sinal Instr[31] 20 vezes à esquerda.
    - Tipo-U (LUI/AUIPC): adicionado caso que extrai Instr[31:12] e concatena
      12 zeros à direita (12'b0), formando palavras com imediato nos 20 bits altos.

[3] pl_control.sv (Unidade de Controle Principal)
    - Adicionado novo sinal de saída: ALUSrcA (2 bits).
        * 2'b00 : Entrada A da ALU recebe o registrador rs1 (padrão)
        * 2'b01 : Entrada A da ALU recebe o contador de programa PC (AUIPC)
        * 2'b10 : Entrada A da ALU recebe o valor constante 0 (LUI)
    - Mapeamento do Opcode OP_IMM: ALUSrc = 1, RegWrite = 1, ALUOp = 2'b11.
    - Mapeamento do Opcode LUI:    ALUSrc = 1, RegWrite = 1, ALUOp = 2'b00, ALUSrcA = 2'b10.
    - Mapeamento do Opcode AUIPC:  ALUSrc = 1, RegWrite = 1, ALUOp = 2'b00, ALUSrcA = 2'b01.

[4] pl_pipe_pkg.sv (Pacote de Registradores de Pipeline)
    - Adicionado o campo 'logic [1:0] alu_src_a' dentro da struct id_ex_t.
    - Permite propagar o seletor ALUSrcA do estágio ID para o estágio EX.

[5] pl_datapath.sv (Caminho de Dados)
    - Adicionada porta de entrada 'ALUSrcA' (2 bits).
    - Registrador ID/EX atualizado para propagar id_ex.alu_src_a.
    - Adicionado multiplexador no estágio EX para a entrada A da ALU (alu_srca):
        * Seleciona entre fwd_srca (registrador com forwarding), id_ex.pc ou 32'b0.
    - Instância da ALU conectada à nova saída do Mux alu_srca.

[6] pl_cpu.sv (Wrapper Topo da CPU)
    - Declarado o barramento interno 'logic [1:0] ALUSrcA'.
    - Interconectada a saída ALUSrcA do módulo 'ctrl' (pl_control) com a entrada
      ALUSrcA do módulo 'datapath' (pl_datapath).


3. TABELA COMPLETA DE SINAIS DE CONTROLE DA ETAPA 02
-------------------------------------------------------------------------------
Opcode  | Instrução | ALUSrc | ALUSrcA | MemtoReg | RegWrite | MemRead | MemWrite | Branch | ALUOp
--------+-----------+--------+---------+----------+----------+---------+----------+--------+-------
0110011 | R-Type    |   0    |  2'b00  |    0     |    1     |    0    |    0     |   0    | 2'b10
0000011 | LW        |   1    |  2'b00  |    1     |    1     |    1    |    0     |   0    | 2'b00
0100011 | SW        |   1    |  2'b00  |    -     |    0     |    0    |    1     |   0    | 2'b00
1100011 | BEQ       |   0    |  2'b00  |    -     |    0     |    0    |    0     |   1    | 2'b01
0010011 | OP-IMM    |   1    |  2'b00  |    0     |    1     |    0    |    0     |   0    | 2'b11
0110111 | LUI       |   1    |  2'b10  |    0     |    1     |    0    |    0     |   0    | 2'b00
0010111 | AUIPC     |   1    |  2'b01  |    0     |    1     |    0    |    0     |   0    | 2'b00


4. FLUXO DE EXECUÇÃO DAS NOVAS INSTRUÇÕES NA ALU
-------------------------------------------------------------------------------
- ADDI  : ALUResult = SrcA (Reg) + ImmExt (12-bit com sinal)
- ANDI  : ALUResult = SrcA (Reg) & ImmExt (12-bit com sinal)
- ORI   : ALUResult = SrcA (Reg) | ImmExt (12-bit com sinal)
- SLTI  : ALUResult = $signed(SrcA) < $signed(ImmExt)
- SLLI  : ALUResult = SrcA << ImmExt[4:0]
- SRLI  : ALUResult = SrcA >> ImmExt[4:0]  (deslocamento lógico com zeros)
- SRAI  : ALUResult = $signed(SrcA) >>> ImmExt[4:0] (preserva o bit de sinal)
- LUI   : ALUResult = 32'b0 + {Instr[31:12], 12'b0}
- AUIPC : ALUResult = PC   + {Instr[31:12], 12'b0}
===============================================================================