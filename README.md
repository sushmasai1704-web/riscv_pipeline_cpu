# RISC-V 5-Stage Pipelined CPU (RV32I)

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
├── sim/ # Simulation outputs (VCD, logs)
├── docs/ # Diagrams or notes
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

- Verified correct instruction execution through simulation
- Observed proper pipeline flow across all stages
- Confirmed hazard handling using waveform analysis

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

## Author

M Sai Sushma
