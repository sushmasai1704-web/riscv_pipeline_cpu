# RISC-V 5-Stage Pipelined CPU (RV32I)

A fully functional, complete RV32I 5-stage pipelined processor implemented in Verilog,
featuring a 2-bit saturating counter branch predictor, full data forwarding, hazard detection,
and support for all six branch types, shift instructions, LUI and AUIPC.

## Key Features
- Complete RV32I base instruction set
- BEQ, BNE, BLT, BGE, BLTU, BGEU branch types
- SLL, SRL, SRA (register and immediate forms)
- LUI and AUIPC upper-immediate instructions
- Full data forwarding (EX->EX and MEM->EX)
- Load-use hazard stall detection
- 2-bit saturating counter branch predictor + BTB
- Self-checking testbench — ALL 14 TESTS PASSED

## Instruction Coverage
| Category      | Instructions                    | Status |
|---------------|---------------------------------|--------|
| R-type ALU    | ADD SUB AND OR XOR SLT SLTU     | done   |
| R-type Shifts | SLL SRL SRA                     | done   |
| I-type ALU    | ADDI ANDI ORI XORI SLTI SLTIU   | done   |
| I-type Shifts | SLLI SRLI SRAI                  | done   |
| Load/Store    | LW SW                           | done   |
| Branch        | BEQ BNE BLT BGE BLTU BGEU       | done   |
| Jump          | JAL JALR                        | done   |
| Upper Imm     | LUI AUIPC                       | done   |

## How to Run
iverilog -o sim/cpu.vvp rtl/pipeline_cpu.v rtl/branch_predictor.v rtl/alu.v rtl/control.v rtl/imm_gen.v rtl/tb_cpu.v
vvp sim/cpu.vvp
gtkwave dump.vcd

## Tools
- Verilog HDL / Icarus Verilog / GTKWave

## Author
M Sai Sushma
https://github.com/sushmasai1704-web/riscv_pipeline_cpu
