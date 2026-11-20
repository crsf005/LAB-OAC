# Processador RISC-V RV32I (Pipeline)

Implementação incremental em **SystemVerilog** de um processador **RISC-V de 32 bits (`RV32I`)** com arquitetura **pipeline de 5 estágios** (`IF`, `ID`, `EX`, `MEM`, `WB`), desenvolvido para a disciplina de Laboratório de Organização e Arquitetura de Computadores (OAC).

O projeto parte de um núcleo base funcional (`ADD`, `SUB`, `AND`, `OR`, `SLT`, `LW`, `SW`, `BEQ`) e evolui em três etapas incrementais até a integração completa validada tanto em **simulação RTL (ModelSim)** quanto em **hardware real (placa FPGA Intel/Altera DE2-115)**.

## Estrutura do Repositório

O repositório está organizado em pastas correspondentes às entregas incrementais do projeto e uma pasta final consolidada para testes e síntese:

```
.
├── ETAPA 1/        # Expansão da ALU e controle da ALU (Instruções Tipo-R) + README técnico
├── ETAPA 2/        # Operações com imediatos (Tipo-I) e imediatos superiores (Tipo-U) + README técnico
├── ETAPA 3/        # Acesso sub-word à memória, desvios completos (Tipo-B) e saltos (Tipo-J/I) + README técnico
├── ETAPA FINAL/    # Projeto completo integrado para simulação no ModelSim e gravação na FPGA DE2-115
└── README.md       # Visão geral do repositório (este arquivo)

```

### Detalhamento das Pastas

| Pasta | Escopo Implementado | Conteúdo | 
| ----- | ----- | ----- | 
| **`ETAPA 1`** | **Instruções Tipo-R:** `XOR`, `SLL`, `SRL`, `SRA`, `SLTU` | Arquivos SystemVerilog modificados no estágio `EX` (`pl_alu.sv` e `pl_alu_ctrl.sv`) acompanhados de um **`README.md` específico** detalhando a decodificação e as operações adicionadas. | 
| **`ETAPA 2`** | **Instruções Tipo-I e Tipo-U:** `ADDI`, `ANDI`, `ORI`, `SLTI`, `SLLI`, `SRLI`, `SRAI`, `XORI`, `LUI`, `AUIPC` | Módulos atualizados nos estágios `ID`, `ID/EX` e `EX` (`pl_control.sv`, `pl_sign_ext.sv`, `pl_alu_ctrl.sv`, `pl_pipe_pkg.sv`, `pl_datapath.sv`, `pl_cpu.sv`) e **`README.md` específico** com o fluxo de dados e sinais de controle. | 
| **`ETAPA 3`** | **Memória Sub-Word, Desvios e Saltos:** `LB`, `LH`, `LBU`, `LHU`, `SB`, `SH`, `BNE`, `BLT`, `BGE`, `BLTU`, `BGEU`, `JAL`, `JALR` | Módulos atualizados para acesso parcial *little-endian* à RAM (`pl_dmem.sv`), resolução de *branches*/*jumps* e *flush* no pipeline, acompanhados de **`README.md` específico**. | 
| **`ETAPA FINAL`** | **Processador RV32I Completo (Integração Final)** | Ambiente unificado com todos os arquivos RTL (`src/`), *testbench* (`pl_cpu_tb.sv`) para validação no **ModelSim**, montador Python (`assembler.py`) e projeto **Quartus Prime** (`pl_top.sv`, PLL de 10 MHz e arquivos `.mif`) para execução na **FPGA DE2-115**. | 

## Características da Arquitetura

* **Pipeline de 5 Estágios:** *Instruction Fetch* (`IF`), *Instruction Decode* (`ID`), *Execute* (`EX`), *Memory Access* (`MEM`) e *Write-Back* (`WB`), isolados por registradores de pipeline estruturados em `pl_pipe_pkg.sv`.

* **Tratamento de *Hazards* de Dados:** Unidade de *forwarding* (`pl_forward.sv`) adiantando resultados de `EX/MEM` e `MEM/WB` diretamente para a ALU, combinada com detecção automática de *load-use* (`pl_hazard.sv`) inserindo *stall* de 1 ciclo quando necessário.

* **Tratamento de *Hazards* de Controle:** Desvios condicionais e saltos incondicionais resolvidos no estágio `EX`, aplicando *flush* síncrono de 2 instruções (`IF/ID` e `ID/EX`) quando o desvio é tomado.

* **Memória e Periféricos (MMIO):** Memória de dados de 32 bits com suporte a escrita e leitura em *byte* (8 bits) e *halfword* (16 bits) no `pl_dmem.sv`, além de interface mapeada em memória (`pl_mmio.sv` e `pl_uart.sv` a 9600 baud) para leitura de chaves/botões, acionamento de LEDs e transmissão do *dump* da RAM via serial na placa DE2-115.

## Como Executar os Testes (`ETAPA FINAL`)

### 1. Simulação RTL no ModelSim

1. Na pasta do montador (`assembler/`), gere o arquivo hexadecimal do programa de teste (sem `--dump`):

   ```
   python assembler.py hello_e2.asm
   
   ```

2. Copie o `program.hex` gerado para a pasta de simulação do ModelSim.

3. Compile os arquivos de `src/` e o *testbench* `pl_cpu_tb.sv` na biblioteca `work`, inicie a simulação de `pl_cpu_tb` e execute **Run -All** para visualizar os registradores e o conteúdo final da memória (`dmem`) no console *Transcript*.

### 2. Síntese e Execução na FPGA DE2-115 (Quartus Prime)

1. Gere os arquivos de inicialização de memória **com a flag `--dump`** para habilitar o envio automático da `dmem` pela porta serial ao término da execução:

   ```
   python assembler.py hello_e2.asm --dump
   
   ```

2. Copie `instruction.mif` e `data.mif` para a pasta raiz do projeto Quartus.

3. Execute **Start Compilation** no Quartus Prime, grave o arquivo `.sof` gerado na placa **DE2-115** via **Programmer** (`USB-Blaster`) e acompanhe a saída pela interface serial UART (9600 baud).