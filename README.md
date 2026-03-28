# RISC-V 5-Stage Pipelined CPU (RV32I)
Designed and verified using simulation with waveform-based validation.
This project implements a 5-stage pipelined RISC-V (RV32I) processor in Verilog.
The design focuses on efficient instruction execution using pipelining along with proper handling of data hazards through forwarding and stalling.

---

## Overview

The processor follows the standard 5-stage pipeline architecture:

- Instruction Fetch (IF)
- Instruction Decode (ID)
- Execute (EX)
- Memory Access (MEM)
- Write Back (WB)

Multiple instructions are processed simultaneously across different stages, improving overall throughput compared to a single-cycle design.

---

## Key Features

- Implementation of RV32I base instruction set
- 5-stage pipeline design
- Data forwarding to minimize stalls
- Hazard detection unit for load-use cases
- Pipeline registers between all stages
- Modular RTL design for clarity and scalability
- Simulation using Verilog testbench
- Supports basic arithmetic, logical, and memory access instructions from RV32I
- Supports R-type, I-type, and load/store instructions

---

## Pipeline Operation

Instructions move through the pipeline stages in sequence:

IF → ID → EX → MEM → WB

At any given clock cycle, different instructions occupy different stages, allowing parallel execution.

---

## Hazard Handling

### Data Hazards
Data dependencies between instructions are resolved using forwarding paths from later stages to earlier ones.

### Load-Use Hazard
When forwarding is not sufficient (e.g., load followed by dependent instruction), the hazard detection unit introduces a stall to ensure correct execution.

---

## Project Structure
riscv_pipeline_cpu/
├── rtl/ # Verilog source files
├── testbench/ # Testbench files
├── sim/ # Simulation outputs
├── docs/ # Diagrams and screenshots
└── README.md

---

## How to Run

### Compile
iverilog -o cpu.vvp *.v

### Run Simulation
vvp cpu.vvp

### View Waveforms
gtkwave dump.vcd

---

## Results

The processor was verified using simulation with multiple instruction sequences.

- Correct execution of arithmetic and memory instructions was observed  
- Pipeline stages showed proper overlap across clock cycles  
- Data hazards were resolved using forwarding without unnecessary stalls  
- Load-use hazards correctly introduced pipeline stalls  

### Example

Instruction sequence:
ADD x1, x2, x3  
SUB x4, x1, x5  

The second instruction uses the result of the first. Forwarding ensures correct execution without stalling.

Waveform analysis confirms:
- Correct register updates  
- Proper stage-wise instruction movement  
- Hazard handling as expected  
<img width="1646" height="792" alt="image" src="https://github.com/user-attachments/assets/2cb2d80d-bf76-4b9e-8eb0-f5ad9be88e2a" />

<img width="1918" height="1073" alt="image" src="https://github.com/user-attachments/assets/1411caf4-486a-465f-9840-7914db3881c7" />

---

## Tools Used

- Verilog HDL  
- Icarus Verilog  
- GTKWave  

---

## What I Learned

- Designing a pipelined processor from scratch  
- Handling data hazards using forwarding and stalling  
- Structuring modular RTL for complex systems  
- Debugging using simulation waveforms  

---

## Possible Improvements

- Branch handling and prediction  
- Cache integration  
- Support for additional RISC-V instructions  
- Performance optimization  

---

## Summary

This project demonstrates practical understanding of pipelined processor design, hazard handling, and RTL implementation using Verilog.

## Author

M Sai Sushma
