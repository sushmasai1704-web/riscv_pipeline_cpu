RISC-V CPU Design in Verilog

- Designed and implemented a 32-bit RISC-V CPU
- Supports instructions: ADD, SUB, AND, OR, XOR, ADDI, LW, SW, BEQ, JAL
- Built pipeline stages: IF, ID, EX, MEM, WB
- Implemented register file with 32 registers (x0–x31)
- Verified functionality using testbench simulations

Features:
- Instruction fetch and decode
- ALU operations
- Memory access
- Branch and jump handling
- Basic pipeline structure

Future Work:
- Data hazard forwarding
- Hazard detection unit
- Branch prediction
