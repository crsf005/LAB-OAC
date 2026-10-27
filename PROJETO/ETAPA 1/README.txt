===============================================================================
  UNIDADE LÓGICA E ARITMÉTICA (ALU) E CONTROLE DA ALU - RISC-V RV32I (PIPELINED)
===============================================================================

1. VISÃO GERAL DO PROJETO
-------------------------------------------------------------------------------
Este projeto implementa os módulos de processamento aritmético e de controle do
estágio de Execução (EX) de um processador em pipeline baseado na arquitetura
RISC-V de 32 bits (RV32I), seguindo a estrutura de Patterson & Hennessy.

O sistema é dividido em dois módulos combinacionais em SystemVerilog:
  - pl_alu_ctrl.sv : Decodificador de controle de 2º nível.
  - pl_alu.sv      : Unidade operacional/calculadora de 32 bits.


2. MÓDULO: pl_alu_ctrl.sv (UNIDADE DE CONTROLE DA ALU)
-------------------------------------------------------------------------------
Função: Traduzir os sinais de controle genéricos e os campos da instrução em
um código de operação de 4 bits (Operation) para a ALU.

Entradas:
  - ALUOp [1:0]   : Código do controlador principal (registrador ID/EX).
                      * 2'b00 : Instruções de Memória (LW, SW) -> Força ADD
                      * 2'b01 : Desvio Condicional (BEQ)      -> Força SUB
                      * 2'b10 : Tipo-R (Aritmética/Lógica)     -> Decodifica Funct
  - Funct7 [6:0]  : Bits [31:25] da instrução RISC-V.
  - Funct3 [2:0]  : Bits [14:12] da instrução RISC-V.

Saídas:
  - Operation [3:0] : Código de 4 bits enviado para a ALU.


3. MÓDULO: pl_alu.sv (UNIDADE LÓGICA E ARITMÉTICA)
-------------------------------------------------------------------------------
Função: Realizar operações aritméticas, lógicas e de deslocamento sobre dois
operandos de 32 bits com base no sinal Operation.

Entradas:
  - SrcA [31:0]     : Primeiro operando (32 bits).
  - SrcB [31:0]     : Segundo operando (32 bits).
  - Operation [3:0] : Código de seleção da operação.

Saídas:
  - ALUResult [31:0]: Resultado do processamento de 32 bits.
  - Zero            : Flag que indica 1 quando ALUResult é igual a 0.


4. TABELA DE OPERAÇÕES E MAPEAMENTO DE INSTRUÇÕES
-------------------------------------------------------------------------------
Instrução | Tipo   | ALUOp | Funct3 | Funct7[5] | Operation | Ação na ALU
----------+--------+-------+--------+-----------+-----------+-----------------------------------
ADD       | R / Mem| 10/00 |  3'h0  |     0     |   4'd01   | $signed(SrcA) + $signed(SrcB)
SUB       | R / Br | 10/01 |  3'h0  |     1     |   4 me02   | $signed(SrcA) - $signed(SrcB)
XOR       | R-type | 2'b10 |  3'h4  |     -     |   4'd03   | SrcA ^ SrcB
OR        | R-type | 2'b10 |  3'h6  |     -     |   4'd04   | SrcA | SrcB
AND       | R-type | 2'b10 |  3'h7  |     -     |   4'd05   | SrcA & SrcB
SLL       | R-type | 2'b10 |  3'h1  |     -     |   4'd06   | SrcA << SrcB[4:0]
SRL       | R-type | 2'b10 |  3'h5  |     0     |   4'd07   | SrcA >> SrcB[4:0]
SRA       | R-type | 2'b10 |  3'h5  |     1     |   4'd08   | $signed(SrcA) >>> SrcB[4:0]
SLT       | R-type | 2'b10 |  3'h2  |     -     |   4'd11   | 32'($signed(SrcA) < $signed(SrcB))
SLTU      | R-type | 2'b10 |  3'h3  |     -     |   4'd12   | 32'(SrcA < SrcB)


5. DETALHES DE IMPLEMENTAÇÃO EM SYSTEMVERILOG
-------------------------------------------------------------------------------
- Bloco always_comb:
  Usado em ambos os módulos para garantir que os sinais sejam atualizados de
  forma puramente combinatória (sem necessidade de clock).

- Deslocamentos (Shifts):
  Utilizam apenas os 5 bits menos significativos de SrcB (SrcB[4:0]), pois em
  uma arquitetura de 32 bits, deslocar mais de 31 posições é redundante (2^5 = 32).

- Operador $signed() e >>>:
  Necessários no SRA (Shift Right Arithmetic) e nas comparações com sinal (SLT)
  para preservar a extensão do bit de sinal em números negativos em complemento
  de dois.


6. CONEXÃO NO ESTÁGIO DE EXECUÇÃO (EX)
-------------------------------------------------------------------------------
  [Instrução] ---> ALUOp, Funct3, Funct7 ---> [pl_alu_ctrl]
                                                   |
                                            Operation (4 bits)
                                                   |
  [SrcA, SrcB] -----------------------------> [pl_alu] ---> ALUResult, Zero
===============================================================================