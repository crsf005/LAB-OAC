# Processador RISC-V RV32I (Pipelined) — Etapa 03: Desvios, Saltos e Acesso Parcial à Memória

## 1. Visão Geral da Etapa 03

Na **Etapa 03** do projeto, o processador **RISC-V de 32 bits (`RV32I`)** em pipeline de 5 estágios foi expandido para suportar **controle de fluxo completo** (saltos incondicionais e todas as variações de desvios condicionais) e **acesso parcial à memória de dados** em granularidade de *byte* (8 bits) e *halfword* (16 bits).

Com a conclusão desta etapa, o núcleo passa a executar todo o conjunto base de instruções de controle de fluxo e transferência de dados da especificação RV32I:

### Instruções Adicionadas

* **Acesso Parcial à Memória (Tipo-I Load e Tipo-S Store):**

  * Leituras com extensão de sinal: **`LB`** (*Load Byte*), **`LH`** (*Load Halfword*)

  * Leituras sem sinal (extensão de zeros): **`LBU`** (*Load Byte Unsigned*), **`LHU`** (*Load Halfword Unsigned*)

  * Escritas parciais: **`SB`** (*Store Byte*), **`SH`** (*Store Halfword*)

* **Desvios Condicionais (Tipo-B — Opcode `7'b1100011`):**

  * Desigualdade: **`BNE`** (*Branch if Not Equal*) — complementando o **`BEQ`** já existente

  * Comparações com sinal: **`BLT`** (*Branch if Less Than*), **`BGE`** (*Branch if Greater or Equal*)

  * Comparações sem sinal: **`BLTU`** (*Branch if Less Than Unsigned*), **`BGEU`** (*Branch if Greater or Equal Unsigned*)

* **Saltos Incondicionais (Tipo-J):**

  * **`JAL`** (*Jump and Link* — Opcode `7'b1101111`): salto relativo ao `PC` com salvamento do endereço de retorno (`PC + 4`) em `rd`.

  * **`JALR`** (*Jump and Link Register* — Opcode `7'b1100111`): salto indireto calculado por `(rs1 + imm) & ~1` com salvamento de `PC + 4` em `rd`.

## 2. Relação Geral com o Pipeline de 5 Estágios

A integração das novas instruções preservou a organização clássica de 5 estágios (`IF` $\rightarrow$ `ID` $\rightarrow$ `EX` $\rightarrow$ `MEM` $\rightarrow$ `WB`), coordenando a resolução de **hazards de controle** no estágio `EX` e o **mascaramento/alinhamento de memória** no estágio `MEM`.

### Percurso das Novas Instruções pelo Pipeline

1. **Estágio `IF` (*Instruction Fetch*):**

   * Busca a instrução em `pl_imem` e calcula `pc_plus4 = pc_reg + 4`.

   * **Redirecionamento de Fluxo (`pc_src`):** Quando o estágio `EX` confirma um desvio condicional tomado (`id_ex.branch && take_branch`) ou um salto incondicional (`id_ex.jump`), o sinal `pc_src` assume nível alto (`1`), carregando `branch_target` em `pc_reg` na borda de subida do clock.

   * **Descarte (*Flush*) de Instruções Especulativas:** Como o desvio ou salto só é resolvido no estágio `EX`, as duas instruções seguintes que já haviam entrado no pipeline (nos estágios `IF` e `ID`) são descartadas simultaneamente via `pc_src`, zerando os registradores `IF/ID` e `ID/EX` (penalidade de 2 ciclos).

2. **Estágio `ID` (*Instruction Decode*):**

   * **Unidade de Controle (`pl_control`):** Reconhece os opcodes `JAL` e `JALR`, ativando o novo sinal `Jump = 1` e `RegWrite = 1` (para gravar `PC + 4` em `rd`). Para `JALR`, ativa também `ALUSrc = 1` para que a ALU calcule `rs1 + imm`. Para `LB`/`LH`/`LBU`/`LHU` e `SB`/`SH`, mantém os mesmos sinais genéricos de `LOAD` e `STORE`, delegando a largura do acesso ao campo `funct3`.

   * **Extensão de Sinal (`pl_sign_ext`):**

     * Para **`JAL`**, reconstrói o imediato de 20 bits embaralhado do formato Tipo-J (`{Instr[31], Instr[19:12], Instr[20], Instr[30:21], 1'b0}`) e estende o bit de sinal para 32 bits.

     * Para **`JALR`**, extrai o imediato de 12 bits do formato Tipo-I (`Instr[31:20]`) com extensão de sinal.

   * **Detecção de Hazards (`pl_hazard`):** A lógica de *load-use stall* continua operando normalmente para `LB`, `LH`, `LBU` e `LHU` (pois todos ativam `id_ex.mem_read = 1`), inserindo 1 bolha caso a instrução seguinte utilize imediatamente o dado carregado.

3. **Estágio `EX` (*Execute*):**

   * **Avaliação dos 6 Desvios Condicionais (`take_branch`):** A `pl_alu_ctrl` configura a ALU para subtração (`BEQ`/`BNE`), comparação com sinal `SLT` (`BLT`/`BGE`) ou comparação sem sinal `SLTU` (`BLTU`/`BGEU`). Em seguida, um bloco combinacional no `pl_datapath` inspeciona `id_ex.funct3` e decide o desvio usando a flag `zero` ou o bit menos significativo `alu_result[0]`.

   * **Cálculo do Endereço Alvo (`branch_target`):**

     * Para **`JALR`** (`id_ex.jump && id_ex.alu_src`), o alvo vem da própria saída da ALU com o bit 0 zerado conforme a especificação RISC-V: `alu_result & ~32'h1`.

     * Para **`JAL`** e **Branches**, o alvo é calculado pelo somador dedicado: `id_ex.pc + id_ex.imm_ext`.

   * **Substituição pelo Endereço de Retorno (`ex_result_final`):** Em instruções de salto (`id_ex.jump == 1`), o sinal `ex_result_final` substitui `alu_result` por `id_ex.pc + 32'd4` antes de gravar no registrador `EX/MEM`. Dessa forma, o endereço de retorno fica imediatamente disponível tanto para escrita em `rd` no estágio `WB` quanto para *forwarding* (`ex_mem.alu_result`) caso a sub-rotina chamada leia o registrador de link (`ra`/`x1`) logo nas primeiras instruções.

4. **Estágio `MEM` (*Memory Access*):**

   * **Propagação de `funct3` e Deslocamento de Byte (`byte_offset`):** O registrador `EX/MEM` transporta `funct3` até o estágio `MEM`, enquanto os dois bits menos significativos do endereço efetivo (`ex_mem.alu_result[1:0]`) fornecem o `byte_offset` dentro da palavra de 32 bits endereçada por `ex_mem.alu_result[9:2]`.

   * **Acesso Sub-Word em `pl_dmem`:** Realiza escritas parciais (`SB`, `SH`) por meio de montagem combinacional *read-modify-write* (`new_word`) e leituras parciais (`LB`, `LH`, `LBU`, `LHU`) com seleção de fatia e extensão de sinal ou de zeros.

5. **Estágio `WB` (*Write-Back*):**

   * Opera sem modificações estruturais: escreve em `rd` o dado vindo da memória (`mem_wb.read_data`, já formatado para 32 bits no caso de `LB`/`LH`/`LBU`/`LHU`) ou o valor vindo de `mem_wb.alu_result` (que contém `PC + 4` no caso de `JAL`/`JALR`).

### Diagrama de Interconexão (Resolução de Saltos/Desvios em `EX` e Acesso Sub-Word em `MEM`)

```
         Estágio EX                                      Estágio MEM
+-----------------------------------+           +---------------------------+
| id_ex.funct3 ---->+-------------+ |           |                           |
| zero / alu_res[0]>| take_branch |-+-> pc_src  | ex_mem.alu_result[9:2] ---+-> addr
| id_ex.jump ------>+-------------+ |   (Flush) | ex_mem.alu_result[1:0] ---+-> byte_offset
|                                   |           | ex_mem.funct3 ------------+-> Funct3
| id_ex.pc + imm ---+-> Mux Target -+-> branch_ | ex_mem.write_data --------+-> WriteData
| alu_result & ~1 --+   (JALR vs    |   target  |                           |      |
|                        JAL/Br)    |           |                     +-----v------+
| id_ex.pc + 4 -----+-> Mux Link ---+-> ex_mem. |                     |  pl_dmem   |
| alu_result -------+   (ex_result_ | alu_result|                     | (SB/SH/SW  |
|                        final)     |           |                     |  LB/LH/LW) |
+-----------------------------------+           +---------------------------+

```

## 3. Resumo dos Arquivos Modificados

Sete arquivos dentro de `src/` foram modificados na **Etapa 03** em relação à versão da Etapa 02:

### 3.1. `pl_pipe_pkg.sv` (Estruturas dos Registradores de Pipeline)

* **`id_ex_t`:** Adicionado o campo `logic jump;` para propagar o controle de salto incondicional (`JAL`/`JALR`) do estágio `ID` para o estágio `EX`.

* **`ex_mem_t`:** Adicionado o campo `logic [2:0] funct3;` para transportar o código de função da instrução do estágio `EX` até o estágio `MEM`, permitindo que `pl_dmem` identifique a largura (`byte`, `halfword` ou `word`) e o tipo de extensão de sinal nos acessos à memória.

### 3.2. `pl_control.sv` (Unidade de Controle Principal)

* **Novos Opcodes:** Declarados `JAL = 7'b1101111` e `JALR = 7'b1100111`.

* **Nova Saída `Jump`:** Criada a saída de 1 bit `Jump` (inicializada em `1'b0` por padrão), ativada exclusivamente pelos opcodes `JAL` e `JALR`.

* **Decodificação de `JAL` e `JALR`:**

  * `JAL`: ativa `RegWrite = 1'b1`, `Jump = 1'b1` e `ALUOp = 2'b00`.

  * `JALR`: ativa `ALUSrc = 1'b1` (seleciona o imediato de 12 bits para somar com `rs1`), `RegWrite = 1'b1`, `Jump = 1'b1` e `ALUOp = 2'b00` (`ADD`).

* **Compatibilidade de `LOAD` e `STORE`:** Os sinais para `LOAD` e `STORE` permaneceram inalterados, pois todas as variantes (`LB`, `LH`, `LW`, `LBU`, `LHU` e `SB`, `SH`, `SW`) compartilham os mesmos opcodes base (`7'b0000011` e `7'b0100011`) e são diferenciadas via `funct3`.

### 3.3. `pl_alu_ctrl.sv` (Decodificador de 2º Nível da ALU)

* **Expansão do ramo `ALUOp == 2'b01` (Branches):** Antes fixado em `4'd02` (`SUB`) apenas para `BEQ`, o caso `2'b01` passou a decodificar `Funct3` para atender a todos os desvios Tipo-B:

  * `3'h0` (`BEQ`) e `3'h1` (`BNE`) $\rightarrow$ `4'd02` (`SUB`, avaliado pela flag `Zero`).

  * `3'h4` (`BLT`) e `3'h5` (`BGE`) $\rightarrow$ `4'd11` (`SLT`, comparação com sinal).

  * `3'h6` (`BLTU`) e `3'h7` (`BGEU`) $\rightarrow$ `4'd12` (`SLTU`, comparação sem sinal).

### 3.4. `pl_sign_ext.sv` (Gerador de Imediatos e Extensão de Sinal)

* **Novos Parâmetros:** Adicionados `JAL = 7'b1101111` e `JALR = 7'b1100111`.

* **Formato Tipo-J (`JAL`):** Implementada a reconstrução do deslocamento embaralhado de 20 bits com alinhamento par (`bit 0 = 1'b0`) e extensão de sinal:

  ```
  JAL: ImmExt = {{11{Instr[31]}}, Instr[31], Instr[19:12], Instr[20], Instr[30:21], 1'b0};
  
  ```

* **Formato Tipo-I (`JALR`):** Agrupado ao caso `LOAD, OP_IMM, JALR` para extrair `Instr[31:20]` com extensão de sinal de 20 bits.

### 3.5. `pl_dmem.sv` (Memória de Dados com Acesso Sub-Word)

* **Novas Portas de Entrada:** Adicionadas `Funct3 [2:0]` e `byte_offset [1:0]` (conectada a `alu_result[1:0]`).

* **Escrita Parcial (*Read-Modify-Write* Combinacional):** Para evitar problemas de inferência de memória RAM no Quartus ao escrever fatias parciais diretamente (`ram[addr][7:0] <= ...`), a escrita foi implementada montando primeiro a palavra completa de 32 bits em `new_word` a partir de `raw_word = ram[addr]`:

  * `SB` (`Funct3[1:0] == 2'b00`): substitui apenas o byte selecionado por `byte_offset` (`00`, `01`, `10` ou `11`).

  * `SH` (`Funct3[1:0] == 2'b01`): substitui a meia-palavra inferior (`byte_offset[1] == 0`) ou superior (`byte_offset[1] == 1`).

  * `SW` (`default`): escreve a palavra inteira `WriteData`.

* **Leitura Parcial com Seleção e Extensão:** Extrai `selected_byte` (via `byte_offset`) e `selected_half` (via `byte_offset[1]`), aplicando extensão de sinal para `LB` (`3'b000`) e `LH` (`3'b001`), ou preenchimento com zeros para `LBU` (`3'b100`) e `LHU` (`3'b101`).

### 3.6. `pl_datapath.sv` (Caminho de Dados)

* **Propagação de Controle:** Adicionada a porta `input logic Jump`, registrada em `id_ex.jump` (zerada no `rst_n` e durante `stall || pc_src`), além da propagação de `id_ex.funct3` para `ex_mem.funct3`.

* **Lógica `take_branch` e `pc_src`:** Implementado multiplexador combinacional em `EX` que avalia `zero`, `!zero`, `alu_result[0]` ou `!alu_result[0]` conforme `id_ex.funct3`, unificando o disparo de desvio/salto em `pc_src = (id_ex.branch && take_branch) || id_ex.jump`.

* **Cálculo de `branch_target` e `ex_result_final`:**

  * `branch_target` escolhe entre `(alu_result & ~32'h1)` para `JALR` e `(id_ex.pc + id_ex.imm_ext)` para `JAL` e desvios condicionais.

  * `ex_result_final` seleciona `(id_ex.pc + 32'd4)` quando `id_ex.jump` está ativo, gravando-o em `ex_mem.alu_result`.

* **Conexão com `pl_dmem`:** Conectadas as novas entradas `.Funct3(ex_mem.funct3)` e `.byte_offset(ex_mem.alu_result[1:0])`.

### 3.7. `pl_cpu.sv` (Módulo Topo da CPU)

* **Roteamento Interno:** Declarado o fio `logic Jump` e interligada a saída `.Jump(Jump)` de `pl_control` à entrada `.Jump(Jump)` de `pl_datapath`.
