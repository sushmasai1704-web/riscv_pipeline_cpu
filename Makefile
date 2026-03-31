# RISC-V Pipeline CPU — Build System

RTL = rtl/pipeline_cpu.v \
      rtl/branch_predictor.v \
      rtl/alu.v \
      rtl/control.v \
      rtl/imm_gen.v \
      rtl/tb_cpu.v

sim: $(RTL)
iverilog -o sim/cpu.vvp $(RTL)
vvp sim/cpu.vvp

wave:
gtkwave dump.vcd cpu.gtkw

clean:
rm -f sim/cpu.vvp dump.vcd

.PHONY: sim wave clean
