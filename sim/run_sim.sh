#!/bin/bash

# Create simulation directory if not exists
mkdir -p sim

# Compile
iverilog -o sim/cpu.vvp \
    rtl/pipeline_cpu.v \
    rtl/alu.v \
    rtl/imm_gen.v \
    rtl/control_simple.v \
    rtl/tb_cpu.v

# Run simulation
vvp sim/cpu.vvp

# View waveform (optional, requires GTKWave)
# gtkwave dump.vcd &
