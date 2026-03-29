# RISC-V 5-Stage Pipelined CPU (RV32I)
 
A fully functional 5-stage pipelined RISC-V (RV32I) processor implemented in Verilog,
featuring a 2-bit saturating counter branch predictor, full data forwarding, and hazard detection.
Verified using a self-checking testbench with waveform-based validation.

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

- RV32I base instruction set (R-type, I-type, Load/Store, Branch, JAL/JALR)
- **2-bit saturating counter branch predictor** with Branch Target Buffer (BTB)
- Full data forwarding (EX→EX and MEM→EX paths)
- Hazard detection unit for load-use stalls
- Pipeline flush on branch misprediction
- Modular RTL — one module per file
- Self-checking testbench with accurate CPI and mispredict tracking

---

## Project Structure

```
riscv_pipeline_cpu/
├── rtl/
│   ├── pipeline_cpu.v      # Top-level pipeline
│   ├── branch_predictor.v  # 2-bit saturating counter BHT + BTB
│   ├── alu.v               # ALU (ADD, SUB, AND, OR, XOR, SLT, shifts)
│   ├── control.v           # Control unit
│   ├── imm_gen.v           # Immediate generator
│   └── tb_cpu.v            # Self-checking testbench
├── sim/                    # Compiled simulation outputs
├── docs/
│   └── branch_predictor.md # Branch predictor deep-dive
├── program.hex             # Test program (hex)
├── .gitignore
└── README.md
```

---

## How to Run

### 1. Compile
```bash
iverilog -o sim/cpu.vvp \
  rtl/pipeline_cpu.v \
  rtl/branch_predictor.v \
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
x1  = 36 (Expected: 36) PASS
x2  = 30 (Expected: 30) PASS
x3  = 30 (Expected: 30) PASS
x4  = 50 (Expected: 50) PASS
x5  = 40 (Expected: 40) PASS
mem[0] = 50 (Expected: 50) PASS
====================================

========== PERFORMANCE ==========
Total cycles     : 16
Instructions     : 9
Stall cycles     : 0
Branch count     : 2
Mispredictions   : 1
CPI              : 1.78
Mispredict rate  : 50.0%
=================================

========== TEST STATUS ==========
ALL TESTS PASSED ✓
=================================
```

Instructions tested: ADDI, ADD, SW, LW, BEQ, JAL — covering arithmetic, memory access,
branching, and jump-and-link.

---

## Performance Analysis

| Metric | Value | Notes |
|---|---|---|
| CPI | 1.78 | 9 instructions, 16 cycles |
| Stall cycles | 0 | Forwarding eliminates data hazards |
| Branch count | 2 | Both resolved correctly after predictor warms up |
| Mispredictions | 1 | Cold predictor — expected on first encounter |
| Mispredict penalty | 2 cycles | IF/ID and ID/EX flushed on miss |

### Pipeline Fill/Drain Visualisation

| Cycle | IF  | ID  | EX  | MEM | WB  | Phase        |
|-------|-----|-----|-----|-----|-----|--------------|
| 1     | I1  | —   | —   | —   | —   | Fill         |
| 2     | I2  | I1  | —   | —   | —   | Fill         |
| 3     | I3  | I2  | I1  | —   | —   | Fill         |
| 4     | I4  | I3  | I2  | I1  | —   | Fill         |
| 5     | I5  | I4  | I3  | I2  | I1  | Steady-state |
| 6     | I6  | I5  | I4  | I3  | I2  | Steady-state |
| ...   | ... | ... | ... | ... | ... | 1 CPI        |
| 12    | —   | —   | —   | I9  | I8  | Drain        |
| 13    | —   | —   | —   | —   | I9  | Drain        |

---

## Hazard Handling

### Data Hazards — Forwarding
Results are forwarded from EX/MEM and MEM/WB stage registers back to the EX stage ALU
inputs, eliminating unnecessary stalls.

```
ADD x1, x2, x3   # result in EX at cycle N
SUB x4, x1, x5   # needs x1 — forwarded from EX/MEM register
```

### Load-Use Hazard — Stall
When a load is immediately followed by a dependent instruction, forwarding alone is
insufficient. The hazard detection unit stalls the pipeline for one cycle.

```
LW  x5, 0(x1)    # data ready after MEM stage
ADD x6, x5, x2   # stall inserted, then MEM→EX forward
```

### Control Hazards — Branch Predictor
The 2-bit saturating counter predictor speculatively redirects the PC at fetch time.
If the prediction is correct, execution continues with zero penalty.
If wrong, IF/ID and ID/EX are flushed (2-cycle penalty).

```
BEQ x1, x2, target   # predictor guesses at IF
                      # resolved at EX — flush only on miss
```

See [docs/branch_predictor.md](docs/branch_predictor.md) for full predictor internals.

---

## Branch Predictor Summary

| Property | Value |
|---|---|
| Type | 2-bit saturating counter BHT |
| Entries | 256 (INDEX_BITS=8) |
| Index | PC[9:2] |
| Target storage | Branch Target Buffer (BTB) |
| Miss penalty | 2 cycles |
| Reset state | Weakly not-taken (2'b01) |

---

## Tools Used

- Verilog HDL
- Icarus Verilog (iverilog)
- GTKWave

---

## Possible Improvements

- Cache hierarchy: L1 I$/D$ with hit-under-miss
- Full RV32I completeness: SLL/SRL/SRA, AUIPC, LUI, remaining branches
- Advanced microarchitecture: out-of-order execution (Tomasulo's algorithm)
- Verification: Spike cosimulation, random test generation

---

## Author

M Sai Sushma  
[github.com/sushmasai1704-web/riscv_pipeline_cpu](https://github.com/sushmasai1704-web/riscv_pipeline_cpu)
