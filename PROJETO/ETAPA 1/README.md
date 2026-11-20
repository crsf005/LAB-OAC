# Processador RISC-V RV32I (Pipelined) — Etapa 01: ALU e Controle da ALU

## 1. Visão Geral da Etapa 01

Este documento descreve a implementação, as modificações realizadas e a integração dos módulos responsáveis pelo processamento aritmético, lógico, de deslocamento e de comparação do estágio de **Execução (`EX`)** de um processador **RISC-V de 32 bits (`RV32I`)** organizado em **pipeline de 5 estágios**, seguindo a arquitetura clássica de *Patterson & Hennessy*.

Na **Etapa 01** do projeto, o núcleo operacional do processador foi expandido para suportar o conjunto completo de instruções **Tipo-R** (*Register-Register*) — incorporando as operações **`XOR`**, **`SLL`**, **`SRL`**, **`SRA`** e **`SLTU`** ao subconjunto básico inicial (`ADD`, `SUB`, `AND`, `OR`, `SLT`) —, mantendo também a compatibilidade com o cálculo de endereços de memória (`LW`, `SW`) e desvios condicionais (`BEQ`).

A arquitetura do estágio de execução divide essa responsabilidade em dois módulos combinacionais em SystemVerilog:

* **`pl_alu_ctrl.sv`**: Unidade de Controle da ALU (decodificador de 2º nível).
* **`pl_alu.sv`**: Unidade Lógica e Aritmética (bloco operacional de 32 bits).

## 2. Comparativo entre a Versão Base e a Etapa 01

Na estrutura inicial do processador (versão base), a ALU suportava apenas o subconjunto mínimo necessário para executar programas simples de soma, subtração, lógica básica, comparação com sinal e acesso à memória (`ADD`, `SUB`, `AND`, `OR`, `SLT`). Para atingir a conformidade com as operações Tipo-R da **Etapa 01**, ambos os arquivos do estágio `EX` foram estendidos.

| Aspecto | Versão Base (Antes) | Etapa 01 (Atual) |
| :--- | :--- | :--- |
| **Instruções Tipo-R Suportadas** | `ADD`, `SUB`, `AND`, `OR`, `SLT` | `ADD`, `SUB`, `AND`, `OR`, `SLT` + **`XOR`**, **`SLL`**, **`SRL`**, **`SRA`**, **`SLTU`** |
| **Decodificação em `pl_alu_ctrl.sv`** | Tratava apenas `Funct3` $\in \{0, 2, 6, 7\}$ quando `ALUOp == 2'b10` | Adicionados os casos `Funct3` $\in \{1, 3, 4, 5\}$ e distinção via `Funct7[5]` para `SRL`/`SRA` |
| **Operações em `pl_alu.sv`** | 5 operações (`4'd01`, `4'd02`, `4'd04`, `4'd05`, `4'd11`) | 10 operações (`4'd01` a `4'd08`, `4'd11` e `4'd12`), incluindo *shifts* de 32 bits e comparação *unsigned* |

### 2.1. Alterações em `pl_alu_ctrl.sv` (Decodificador de 2º Nível)

No arquivo original, o bloco `case (Funct3)` dentro de `ALUOp == 2'b10` possuía apenas quatro entradas (`3'h0`, `3'h2`, `3'h6` e `3'h7`), fazendo com que qualquer outra instrução Tipo-R caísse no `default` (executando `ADD`). Na Etapa 01, foram adicionadas quatro novas ramificações de decodificação:

1. **`3'h1`** $\rightarrow$ **`4'd06` (`SLL`):** Mapeia o código de deslocamento lógico à esquerda.
2. **`3'h3`** $\rightarrow$ **`4'd12` (`SLTU`):** Mapeia a comparação *Set Less Than Unsigned* (distinta de `SLT`, que usa `3'h2` $\rightarrow$ `4'd11`).
3. **`3'h4`** $\rightarrow$ **`4'd03` (`XOR`):** Mapeia a operação lógica OU-exclusivo bit a bit.
4. **`3'h5`** $\rightarrow$ **`Funct7[5] ? 4'd08 : 4'd07` (`SRA` / `SRL`):** Assim como ocorre entre `ADD` e `SUB` no caso `3'h0`, o deslocamento à direita compartilha o mesmo `Funct3 = 3'h5`. O decodificador passou a inspecionar o bit 30 da instrução (`Funct7[5]`):
   * Quando `Funct7[5] == 1'b0`, gera `4'd07` (**`SRL`** — deslocamento lógico).
   * Quando `Funct7[5] == 1'b1`, gera `4'd08` (**`SRA`** — deslocamento aritmético).

*(Nota arquitetural: essa estrutura de decodificação também deixa o caminho pronto para as variantes imediatas `XORI`, `SLLI`, `SRLI`, `SRAI` e `SLTIU` nas etapas seguintes do projeto).*

### 2.2. Alterações em `pl_alu.sv` (Unidade Operacional)

No arquivo original, a `pl_alu` realizava apenas soma, subtração, `AND`, `OR` e comparação com sinal (`SLT`). Na Etapa 01, cinco novos ramos foram implementados dentro do `case (Operation)`:

1. **OU-Exclusivo (`4'd03` — `XOR`):** Implementado com o operador bit a bit `SrcA ^ SrcB`.
2. **Deslocamento Lógico à Esquerda (`4'd06` — `SLL`):** Implementado com `SrcA << SrcB[4:0]`, preenchendo os bits menos significativos com zeros.
3. **Deslocamento Lógico à Direita (`4'd07` — `SRL`):** Implementado com `SrcA >> SrcB[4:0]`, deslocando os bits para a direita e preenchendo os bits mais significativos com zeros, independentemente do sinal de `SrcA`.
4. **Deslocamento Aritmético à Direita (`4'd08` — `SRA`):** Implementado com `$signed(SrcA) >>> SrcB[4:0]`. Diferente do `SRL`, esta operação exige o *cast* explícito `$signed(SrcA)` combinado ao operador `>>>` para que o sintetizador replique o bit de sinal (`SrcA[31]`) nas posições vagas à esquerda.
5. **Comparação Sem Sinal (`4'd12` — `SLTU`):** Implementado com `32'(SrcA < SrcB)`. Enquanto o `SLT` (`4'd11`) utiliza `$signed(SrcA) < $signed(SrcB)` para comparar valores em complemento de dois, o `SLTU` compara os operandos diretamente como magnitudes sem sinal de 32 bits.

## 3. Relação com o Pipeline de 5 Estágios

No pipeline clássico do RISC-V (`IF` $\rightarrow$ `ID` $\rightarrow$ `EX` $\rightarrow$ `MEM` $\rightarrow$ `WB`), os módulos `pl_alu_ctrl` e `pl_alu` residem inteiramente no **terceiro estágio (`EX` — *Execute*)**.

### Fluxo de Dados e Controle no Estágio `EX`

1. **Entradas vindas do estágio `ID` (via registrador de pipeline `ID/EX`):**
   * A unidade de controle principal (`pl_control`) decodifica o `opcode` no estágio `ID` e gera o sinal abstrato **`ALUOp[1:0]`**, que atravessa o registrador `ID/EX`.
   * Os campos **`Funct3` (`instr[14:12]`)** e **`Funct7` (`instr[31:25]`)**, além dos dados lidos do banco de registradores (`rs1` e `rs2`) e do imediato estendido (`ImmExt`), também são registrados em `ID/EX`.

2. **Adiantamento (*Forwarding*) e Seleção de Operandos (`SrcA` e `SrcB`):**
   * Antes de chegarem à `pl_alu`, os operandos passam pelos multiplexadores da unidade de *forwarding* (`pl_forward`) para resolver dependências de dados (*RAW hazards*) provenientes dos estágios `MEM` ou `WB`.
   * O operando **`SrcB`** passa adicionalmente pelo multiplexador controlado por `ALUSrc`, que seleciona `rs2` (para instruções Tipo-R) ou `ImmExt` (para o cálculo de endereço de `LW` e `SW`).

3. **Saídas para o estágio `MEM` (via registrador `EX/MEM`) e Controle de Desvio:**
   * A saída **`ALUResult`** é armazenada no registrador `EX/MEM` para ser gravada no banco de registradores no estágio `WB` (instruções aritméticas/lógicas) ou usada como endereço na memória de dados `pl_dmem` (`LW`/`SW`).
   * A flag **`Zero`** alimenta a lógica de decisão de desvio no estágio `EX` para determinar se o desvio condicional (`BEQ`) deve alterar o `PC`.

### Diagrama de Interconexão no Estágio `EX`

```text
Registrador ID/EX                                         Registrador EX/MEM
+-----------------+                                       +------------------+
| ALUOp [1:0]     |--->+---------------+                  |                  |
| Funct7 [6:0]    |--->|  pl_alu_ctrl  |                  |                  |
| Funct3 [2:0]    |--->+---------------+                  |                  |
|                 |            |                          |                  |
|                 |     Operation [3:0]                   |                  |
|                 |            v                          |                  |
| rs1 (Fwd)       |--->+---------------+                  |                  |
|                 |    |    pl_alu     |---> ALUResult -->|---> ALUResult    |
| rs2 / Imm (Fwd) |--->+---------------+                  |                  |
+-----------------+            |                          +------------------+
                               +-----------> Zero -------> [Lógica de Branch]
```

## 4. Tabela Completa de Operações e Mapeamento de Instruções

A tabela abaixo consolida todas as operações configuradas nos módulos `pl_alu_ctrl.sv` e `pl_alu.sv`, destacando as instruções adicionadas na **Etapa 01**:

| Instrução | Origem | Categoria | `ALUOp` | `Funct3` | `Funct7[5]` | `Operation` | Expressão em SystemVerilog (`pl_alu`) |
| :--- | :--- | :--- | :---: | :---: | :---: | :---: | :--- |
| **`ADD`** / `LW` / `SW` | Base | R-type / Mem | `2'b10` / `2'b00` | `3'h0` | `0` | `4'd01` | `$signed(SrcA) + $signed(SrcB)` |
| **`SUB`** / `BEQ` | Base | R-type / Branch | `2'b10` / `2'b01` | `3'h0` | `1` | `4'd02` | `$signed(SrcA) - $signed(SrcB)` |
| **`XOR`** | **Etapa 01** | R-type | `2'b10` | `3'h4` | `-` | `4'd03` | `SrcA ^ SrcB` |
| **`OR`** | Base | R-type | `2'b10` | `3'h6` | `-` | `4'd04` | `SrcA \| SrcB` |
| **`AND`** | Base | R-type | `2'b10` | `3'h7` | `-` | `4'd05` | `SrcA & SrcB` |
| **`SLL`** | **Etapa 01** | R-type | `2'b10` | `3'h1` | `-` | `4'd06` | `SrcA << SrcB[4:0]` |
| **`SRL`** | **Etapa 01** | R-type | `2'b10` | `3'h5` | `0` | `4'd07` | `SrcA >> SrcB[4:0]` |
| **`SRA`** | **Etapa 01** | R-type | `2'b10` | `3'h5` | `1` | `4'd08` | `$signed(SrcA) >>> SrcB[4:0]` |
| **`SLT`** | Base | R-type | `2'b10` | `3'h2` | `-` | `4'd11` | `32'($signed(SrcA) < $signed(SrcB))` |
| **`SLTU`** | **Etapa 01** | R-type | `2'b10` | `3'h3` | `-` | `4'd12` | `32'(SrcA < SrcB)` |