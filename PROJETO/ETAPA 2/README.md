# Processador RISC-V RV32I (Pipelined) — Etapa 02: Instruções Tipo-I e Tipo-U

## 1. Visão Geral da Etapa 02

Na **Etapa 02** do projeto, o processador RISC-V de 32 bits (`RV32I`) em pipeline de 5 estágios foi expandido para suportar operações aritméticas, lógicas e de deslocamento com **operandos imediatos (Tipo-I)**, além das instruções de **imediato superior (Tipo-U)** utilizadas na construção de constantes de 32 bits e endereçamento relativo ao contador de programa (`PC`).

### Instruções Adicionadas

* **Tipo-I (`OP-IMM` — Opcode `7'b0010011`):**

  * Aritméticas e de comparação: **`ADDI`**, **`SLTI`** *(e `SLTIU` via decodificador)*

  * Lógicas bit a bit: **`ANDI`**, **`ORI`**, **`XORI`**

  * Deslocamentos por imediato: **`SLLI`**, **`SRLI`**, **`SRAI`**

* **Tipo-U (Imediato Superior de 20 bits):**

  * **`LUI`** (*Load Upper Immediate* — Opcode `7'b0110111`): carrega um imediato nos 20 bits mais significativos de `rd`, preenchendo os 12 bits inferiores com zero.

  * **`AUIPC`** (*Add Upper Immediate to PC* — Opcode `7'b0010111`): soma o imediato deslocado de 12 bits ao valor atual do `PC` e armazena o resultado em `rd`.

## 2. Relação Geral com o Pipeline de 5 Estágios

Para suportar instruções imediatas e de imediato superior sem aumentar o número de estágios do processador (`IF` $\rightarrow$ `ID` $\rightarrow$ `EX` $\rightarrow$ `MEM` $\rightarrow$ `WB`), as alterações foram distribuídas de forma coordenada entre a decodificação, os registradores intermediários do pipeline e a seleção de operandos da ALU.

### Percurso das Novas Instruções pelo Pipeline

1. **Estágio `IF` (*Instruction Fetch*):**

   * Busca a instrução de 32 bits na memória de instruções (`pl_imem`) e registra tanto a instrução quanto o valor corrente de `pc_reg` no registrador de pipeline **`IF/ID`**.

   * **Relação com a Etapa 02:** Propagar o `PC` junto com a instrução no registrador `IF/ID` (e depois para `ID/EX`) é indispensável para que a instrução **`AUIPC`** utilize no estágio `EX` o endereço exato onde ela própria foi buscada, e não o `PC` já incrementado das instruções seguintes.

2. **Estágio `ID` (*Instruction Decode*):**

   * **Decodificação de Controle (`pl_control`):** Reconhece os novos opcodes (`OP_IMM`, `LUI` e `AUIPC`), ativando `ALUSrc = 1` (para que a entrada B da ALU utilize o imediato em vez de `rs2`) e `RegWrite = 1`. Além disso, gera o novo sinal de controle de 2 bits **`ALUSrcA`**, que define qual fonte alimentará a entrada A da ALU no estágio seguinte.

   * **Geração de Imediatos (`pl_sign_ext`):** Extrai os bits do imediato conforme o formato da instrução:

     * Para instruções **Tipo-I (`OP_IMM`)**, extrai os 12 bits `Instr[31:20]` e realiza extensão de sinal para 32 bits.

     * Para instruções **Tipo-U (`LUI`/`AUIPC`)**, extrai os 20 bits `Instr[31:12]` e preenche os 12 bits inferiores com zeros.

   * **Propagação via Registrador `ID/EX` (`pl_pipe_pkg.sv`):** A estrutura `id_ex_t` foi ampliada com o campo `alu_src_a[1:0]`. Em situações de *reset*, *load-use stall* ou *flush* de desvio (`stall || pc_src`), esse campo é zerado (`2'b00`) juntamente com os demais sinais de controle, garantindo que bolhas injetadas no pipeline não alterem o fluxo de execução.

3. **Estágio `EX` (*Execute*):**

   * **Interação com *Forwarding* (`pl_forward`) e Seleção de `SrcA`:**

     * Para instruções Tipo-I (`ADDI`, `ANDI`, `XORI`, etc.), o operando `rs1` passa primeiro pelo multiplexador da unidade de *forwarding* (`fwd_srca`) para resolver possíveis dependências de dados (*RAW hazards*) com instruções nos estágios `MEM` ou `WB`.

     * Em seguida, um novo multiplexador 3-para-1 controlado por `id_ex.alu_src_a` seleciona a entrada efetiva **`alu_srca`** da ALU:

       * `2'b00`: recebe `fwd_srca` (instruções Tipo-R, Tipo-I, `LW`, `SW`, `BEQ`).

       * `2'b01`: recebe `id_ex.pc` (instrução **`AUIPC`**).

       * `2'b10`: recebe `32'b0` (instrução **`LUI`**).

   * **Seleção de `SrcB`:** Com `id_ex.alu_src = 1`, o multiplexador da entrada B ignora `fwd_srcb` e entrega `id_ex.imm_ext` diretamente à ALU. Note-se que, como `LUI` e `AUIPC` não possuem registradores fonte (`rs1`/`rs2`), selecionar `32'b0` ou `id_ex.pc` em `alu_srca` e `imm_ext` em `alu_srcb` isola completamente a execução contra falsos adiantamentos da unidade de *forwarding*.

   * **Reaproveitamento da ALU (`pl_alu_ctrl` e `pl_alu`):**

     * Instruções `OP-IMM` usam `ALUOp = 2'b11` para decodificar `Funct3` sem confundir imediatos negativos de `ADDI` com subtração.

     * Instruções `LUI` e `AUIPC` reutilizam `ALUOp = 2'b00` (mesmo código de soma de endereços de `LW`/`SW`), fazendo a ALU somar `0 + ImmExt` (no caso de `LUI`) ou `PC + ImmExt` (no caso de `AUIPC`).

4. **Estágio `MEM` (*Memory Access*):**

   * Todas as instruções adicionadas na Etapa 02 são puramente computacionais (`MemRead = 0`, `MemWrite = 0`). O resultado `ALUResult` apenas atravessa o registrador `EX/MEM` sem interagir com `pl_dmem` ou `pl_mmio`, mas já fica disponível no barramento `ex_mem.alu_result` para *forwarding* (`2'b10`) caso a instrução imediatamente seguinte dependa desse resultado.

5. **Estágio `WB` (*Write Back*):**

   * Com `MemtoReg = 0` e `RegWrite = 1`, o valor calculado pela ALU é selecionado em `wb_data` e gravado no registrador de destino `rd` do banco de registradores (`pl_regfile`) na borda de subida do clock.

### Diagrama de Interconexão (Estágios `ID` $\rightarrow$ `ID/EX` $\rightarrow$ `EX`)

```
       Estágio ID                Reg. ID/EX                 Estágio EX
+-----------------------+       +----------+       +---------------------------+
| pl_control            |       |          |       |                           |
|   Opcode ------------>|------>| alu_src_a|------>| Mux SrcA (3:1):           |
|                       |       |          |       |  00 -> fwd_srca (rs1)     |
| pl_regfile            |       |          |       |  01 -> id_ex.pc   (AUIPC) |
|   rs1 --------------->|------>| rd1      |------>|  10 -> 32'b0      (LUI)   |---> SrcA --+
|                       |       |          |       |                           |            v
| pl_sign_ext           |       |          |       | Mux SrcB (2:1):           |       +--------+
|   Instr ------------->|------>| imm_ext  |------>|  0  -> fwd_srcb (rs2)     |       | pl_alu |
|                       |       | alu_src  |------>|  1  -> id_ex.imm_ext      |---> SrcB --+
|                       |       |          |       |                           |            ^
|                       |       | alu_op   |------>| pl_alu_ctrl               |            |
|                       |       | funct3/7 |------>|  (ALUOp = 2'b11 p/ I-type)|--> Op -----+
+-----------------------+       +----------+       +---------------------------+

```

## 3. Resumo Detalhado dos Arquivos Modificados

Seis módulos do hardware foram atualizados para integrar as instruções Tipo-I e Tipo-U ao pipeline:

### 3.1. `pl_alu_ctrl.sv` (Controle de 2º Nível da ALU)

* **Adição do código `ALUOp = 2'b11`:** Criado um ramo exclusivo para instruções imediatas (`OP-IMM`), separando-as das instruções Tipo-R (`ALUOp = 2'b10`).

* **Proteção contra falso `SUB` no `ADDI`:** No RISC-V, instruções Tipo-I não possuem campo `funct7` — os bits `[31:25]` fazem parte do valor imediato de 12 bits. Se `ADDI` compartilhasse a mesma regra de `ADD`/`SUB` do Tipo-R (`Funct7[5] ? SUB : ADD`), qualquer soma com imediato negativo (onde o bit 30 vale `1`, como `addi x12, x0, -16`) seria executada incorretamente como subtração. Com `ALUOp = 2'b11`, o caso `3'h0` (`ADDI`) ignora `Funct7[5]` e força sempre `4'd01` (`ADD`).

* **Distinção entre `SRLI` e `SRAI`:** No caso `3'h5`, a verificação de `Funct7[5]` (bit 30 da instrução) foi mantida, pois a especificação RV32I utiliza esse bit como modificador de deslocamento lógico (`0` $\rightarrow$ `4'd07`, `SRLI`) versus aritmético (`1` $\rightarrow$ `4'd08`, `SRAI`).

### 3.2. `pl_sign_ext.sv` (Gerador de Imediatos / Extensão de Sinal)

* **Novos parâmetros de opcode:** Declarados `OP_IMM = 7'b0010011`, `LUI = 7'b0110111` e `AUIPC = 7'b0010111`.

* **Formato Tipo-I (`OP_IMM`):** Agrupado ao caso `LOAD`, extraindo os 12 bits superiores `Instr[31:20]` e replicando o bit de sinal `Instr[31]` 20 vezes à esquerda (`{{20{Instr[31]}}, Instr[31:20]}`).

* **Formato Tipo-U (`LUI` e `AUIPC`):** Adicionado ramo específico que posiciona `Instr[31:12]` nos 20 bits mais significativos e preenche os 12 bits inferiores com zeros (`{Instr[31:12], 12'b0}`).

### 3.3. `pl_control.sv` (Unidade de Controle Principal)

* **Nova saída `ALUSrcA [1:0]`:** Adicionado sinal de 2 bits para controlar o multiplexador da entrada A da ALU:

  * `2'b00`: seleciona o registrador `rs1` (padrão para Tipo-R, Tipo-I, `LW`, `SW` e `BEQ`).

  * `2'b01`: seleciona o `PC` (usado por `AUIPC`).

  * `2'b10`: seleciona a constante `32'b0` (usado por `LUI`).

* **Decodificação dos novos opcodes:**

  * `OP_IMM`: ativa `ALUSrc = 1`, `RegWrite = 1`, `ALUOp = 2'b11` e `ALUSrcA = 2'b00`.

  * `LUI`: ativa `ALUSrc = 1`, `RegWrite = 1`, `ALUOp = 2'b00` (soma) e `ALUSrcA = 2'b10` (`0`).

  * `AUIPC`: ativa `ALUSrc = 1`, `RegWrite = 1`, `ALUOp = 2'b00` (soma) e `ALUSrcA = 2'b01` (`PC`).

### 3.4. `pl_pipe_pkg.sv` (Pacote de Estruturas do Pipeline)

* **Atualização de `id_ex_t`:** Incluído o campo `logic [1:0] alu_src_a` na estrutura do registrador intermediário `ID/EX`, permitindo que a decisão de controle tomada em `ID` acompanhe a instrução até o estágio `EX`.

### 3.5. `pl_datapath.sv` (Caminho de Dados)

* **Entrada e propagação:** Adicionada a porta `input logic [1:0] ALUSrcA` e conectada à lógica sequencial do registrador `id_ex` (com limpeza para `2'b00` em *reset*, *stall* ou *flush*).

* **Multiplexador da entrada A (`alu_srca`):** Implementado bloco combinacional `always_comb` no estágio `EX` que seleciona entre `fwd_srca`, `id_ex.pc` e `32'b0`, conectando a saída diretamente à porta `.SrcA` da instância `pl_alu`.

### 3.6. `pl_cpu.sv` (Wrapper de Topo da CPU)

* **Interconexão de topo:** Declarado o fio interno `logic [1:0] ALUSrcA` ligando a saída `.ALUSrcA` do módulo `ctrl` (`pl_control`) à entrada `.ALUSrcA` do módulo `datapath` (`pl_datapath`).

## 4. Tabela Completa de Sinais de Controle (Etapa 02)

| Opcode | Instrução | `ALUSrc` | `ALUSrcA` | `MemtoReg` | `RegWrite` | `MemRead` | `MemWrite` | `Branch` | `ALUOp` | 
| ----- | ----- | ----- | ----- | ----- | ----- | ----- | ----- | ----- | ----- | 
| `0110011` | **R-Type** | `0` | `2'b00` | `0` | `1` | `0` | `0` | `0` | `2'b10` | 
| `0000011` | **`LW`** | `1` | `2'b00` | `1` | `1` | `1` | `0` | `0` | `2'b00` | 
| `0100011` | **`SW`** | `1` | `2'b00` | `-` | `0` | `0` | `1` | `0` | `2'b00` | 
| `1100011` | **`BEQ`** | `0` | `2'b00` | `-` | `0` | `0` | `0` | `1` | `2'b01` | 
| `0010011` | **`OP-IMM` (Etapa 02)** | `1` | `2'b00` | `0` | `1` | `0` | `0` | `0` | `2'b11` | 
| `0110111` | **`LUI` (Etapa 02)** | `1` | `2'b10` | `0` | `1` | `0` | `0` | `0` | `2'b00` | 
| `0010111` | **`AUIPC` (Etapa 02)** | `1` | `2'b01` | `0` | `1` | `0` | `0` | `0` | `2'b00` | 
