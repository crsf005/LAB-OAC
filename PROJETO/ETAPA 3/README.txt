=============================================================================
               PROJETO PROCESSADOR RISC-V (RV32I) PIPELINED
                                 ETAPA 03
=============================================================================

1. VISÃO GERAL
-----------------------------------------------------------------------------
A Etapa 03 teve como objetivo expandir as capacidades da CPU RISC-V (RV32I) 
para suportar instruções avançadas de controle de fluxo e acesso parcial à 
memória. Com a conclusão desta etapa, o processador agora é capaz de lidar 
com saltos incondicionais, todas as variações de desvios condicionais e 
acessos a dados de 8 bits (byte) e 16 bits (halfword).


2. INSTRUÇÕES ADICIONADAS
-----------------------------------------------------------------------------
* Acesso à Memória (I-type load e S-type):
  - LB (Load Byte), LBU (Load Byte Unsigned)
  - LH (Load Halfword), LHU (Load Halfword Unsigned)
  - SB (Store Byte)
  - SH (Store Halfword)

* Desvios Condicionais (B-type):
  - BNE (Branch if Not Equal)
  - BLT (Branch if Less Than), BGE (Branch if Greater or Equal)
  - BLTU (Branch if Less Than Unsigned), BGEU (Branch if Greater or Equal Unsigned)

* Saltos Incondicionais (J-type e I-type):
  - JAL (Jump and Link)
  - JALR (Jump and Link Register)


3. ESTRUTURA DO PIPELINE (5 ESTÁGIOS)
-----------------------------------------------------------------------------
O processador utiliza uma arquitetura de pipeline de 5 estágios, isolados 
pelos registradores de estado definidos no pacote 'pl_pipe_pkg.sv':

* [IF] Instruction Fetch: Busca a instrução usando o PC atual e calcula PC+4.
* [ID] Instruction Decode: Decodifica o opcode, lê os registradores no 
       'pl_regfile', extrai imediatos no 'pl_sign_ext' e detecta riscos de 
       Load-Use no 'pl_hazard'.
* [EX] Execute: Executa a operação na ALU ('pl_alu'), avalia condições de 
       desvio, resolve riscos RAW via 'pl_forward' e calcula o endereço 
       alvo para branches e jumps.
* [MEM] Memory: Lê ou escreve na memória de dados ('pl_dmem'), agora com 
        mascaramento de bytes e halfwords.
* [WB] Write-Back: Escreve o resultado (da ALU, da memória, ou PC+4) de 
       volta no banco de registradores.


4. ARQUIVOS ALTERADOS NA PASTA SRC/
-----------------------------------------------------------------------------
Para suportar as novas instruções, os seguintes arquivos foram modificados:

* pl_pipe_pkg.sv:
  - Adicionado o campo 'logic jump;' à estrutura 'id_ex_t' para propagar a 
    condição de salto incondicional do estágio ID para o EX.

* pl_control.sv:
  - Adicionados os Opcodes de JAL e JALR.
  - Criada a saída 'Jump', ativada exclusivamente por JAL e JALR.
  - Sinais de LOAD e STORE originais mantidos (a diferenciação de tamanho 
    foi delegada ao dmem).

* pl_alu_ctrl.sv:
  - Atualizada a lógica de Branches (ALUOp = 2'b01) para decodificar o 'Funct3'.
  - Atribui operações de subtração (SUB) para BEQ/BNE e operações de 
    comparação (SLT/SLTU) para os demais branches.

* pl_sign_ext.sv:
  - Adicionada a extração e extensão de sinal embaralhada do formato J-type (JAL).
  - Incluído o JALR no mesmo comportamento de extensão do I-type.

* pl_dmem.sv:
  - Adicionadas as portas 'Funct3' (3 bits) e 'byte_offset' (2 bits).
  - Escrita: Implementado mascaramento para alterar partes específicas da 
    palavra de 32 bits (SB, SH).
  - Leitura: Implementada seleção de byte/halfword seguida de extensão de 
    sinal (LB, LH) ou extensão de zeros (LBU, LHU).

* pl_datapath.sv:
  - Integrado o sinal 'Jump' e a verificação do 'Funct3' para desvios.
  - Implementada a lógica 'take_branch', que avalia as flags 'zero' ou 
    'alu_result[0]' dependendo do branch.
  - Atualizado o somador de 'branch_target' para suportar o cálculo de JALR.
  - Adicionada a lógica para salvar PC+4 no registrador de destino (rd) 
    em caso de jumps.
  - Conectadas as novas portas do 'pl_dmem'.

* pl_cpu.sv (Top-Level):
  - Declarado o fio 'Jump'.
  - Realizado o roteamento do sinal 'Jump' da Unidade de Controle ('ctrl') 
    para o Caminho de Dados ('datapath').


5. ARQUIVOS MANTIDOS INTACTOS
-----------------------------------------------------------------------------
Estes módulos já possuíam hardware suficiente para a Etapa 03:
* pl_alu.sv: Já continha as instruções SLT, SLTU e SUB.
* pl_hazard.sv: A detecção de Load-Use cobre os novos acessos e saltos.
* pl_forward.sv: O adiantamento EX/MEM e MEM/WB atende aos novos operandos.

=============================================================================
