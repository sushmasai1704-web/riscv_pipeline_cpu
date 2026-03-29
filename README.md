# RISC-V 5-Stage Pipelined CPU (RV32I)

A fully functional 5-stage pipelined RISC-V (RV32I) processor implemented in Verilog,
verified using a self-checking testbench with waveform-based validation.

---

## Overview

The processor implements the classic 5-stage pipeline:
```
IF → ID → EX → MEM → WB
```

![Pipeline diagram](https://github.com/user-attachments/assets/1a822a68-3222-452e-8423-2f66ac5e482e)

Multiple instructions execute simultaneously across different stages,
improving throughput over a single-cycle design.

---

## Key Features

- RV32I base instruction set (R-type, I-type, Load/Store, Branch, JAL)
- Full data forwarding (EX→EX and MEM→EX paths)
- Hazard detection unit for load-use stalls and branch flush
- Pipeline registers between all stages
- Modular RTL — one module per file
- Self-checking testbench with pass/fail output


---

## Project Structure
```
riscv_pipeline_cpu/
├── rtl/
│   ├── pipeline_cpu.v   # Top-level pipeline
│   ├── alu.v            # ALU (ADD, SUB, AND, OR, XOR, SLT)
│   ├── control.v        # Control unit
│   ├── imm_gen.v        # Immediate generator
│   ├── reg_file.v       # Register file
│   └── tb_cpu.v         # Self-checking testbench
├── sim/                 # Simulation scripts
├── tb/                  # Unit testbenches
├── program.hex          # Test program (hex)
└── README.md
```

---

## How to Run

### 1. Compile
```bash
iverilog -o sim/cpu.vvp \
  rtl/pipeline_cpu.v \
  rtl/alu.v \
  rtl/control.v \
  rtl/imm_gen.v \
  rtl/tb_cpu.v
```

### 2. Run Simulation
```bash
vvp sim/cpu.vvp
```

### 3. View Waveforms
```bash
gtkwave dump.vcd
```
![Waveform 1](https://github.com/user-attachments/assets/0db5977e-159d-4fca-a1ab-7e2c0c7f0dc8)

![Waveform 2](https://github.com/user-attachments/assets/fb872e42-c9cf-43a0-849a-9a7436f4bbce)
---

## Verified Test Results
```
========== FINAL RESULTS ==========
x1  = 36 (Expected: 36 - JAL return address) PASS
x2  = 30 (Expected: 30) PASS
x3  = 30 (Expected: 30) PASS
x4  = 50 (Expected: 50) PASS
x5  = 40 (Expected: 40) PASS
mem[0] = 50 (Expected: 50) PASS
====================================

========== PERFORMANCE ==========
Total cycles  : 30
Instructions  : 10
Stall cycles  : 0
CPI           : 3.00
=================================

========== TEST STATUS ==========
ALL TESTS PASSED ✓
=================================
```

Instructions tested: ADDI, ADD, SW, LW, BEQ, JAL — covering
arithmetic, memory access, branching, and jump-and-link.

---

## Hazard Handling

### Data Hazards — Forwarding
Results are forwarded from EX/MEM and MEM/WB stage registers
back to the EX stage ALU inputs, eliminating unnecessary stalls.

**Example:**
```
ADD x1, x2, x3   # result in EX at cycle N
SUB x4, x1, x5   # needs x1 — forwarded from EX/MEM register
```

### Load-Use Hazard — Stall
When a load is immediately followed by a dependent instruction,
forwarding alone is insufficient. The hazard detection unit stalls
the pipeline for one cycle, then forwards from MEM/WB.
```
LW  x5, 0(x1)    # data ready after MEM stage
ADD x6, x5, x2   # stall inserted, then MEM→EX forward
```
### Control Hazards — Branch Flush
When a branch is taken, the incorrectly fetched instruction is killed.
The pipeline flushes both IF/ID and ID/EX registers, inserting NOP
bubbles to prevent wrong instructions from executing.
```
BEQ x1, x2, +8      # branch taken (x1 == x2)
ADDI x3, x0, 20     # FLUSHED — never executes
ADDI x3, x0, 20     # correct target — executes
```

Verified by testbench — x3 = 20 confirms the flushed instruction
was correctly killed. 2-cycle branch penalty on taken branches.

---

## Tools Used

- Verilog HDL
- Icarus Verilog (iverilog)
- GTKWave

---

## Possible Improvements

- Branch prediction (2-bit saturating counter BHT)
- Instruction/data cache integration
- Full RV32I instruction support (shifts, AUIPC, LUI)
- Performance counters (CPI tracking)
- 2-bit saturating counter branch predictor (reduce 2-cycle penalty)
...

## Author

M Sai Sushma  
[github.com/sushmasai1704-web/riscv_pipeline_cpu](https://github.com/sushmasai1704-web/riscv_pipeline_cpu)
