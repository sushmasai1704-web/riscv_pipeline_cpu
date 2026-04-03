// ============================================================
// File   : rtl/tb_cpu.v
// Description: Self-checking testbench for the RISC-V RV32I
//              single-cycle CPU.
//
//  What it does
//  ------------
//  1. Instantiates a minimal CPU top (defined inline below).
//  2. Loads a small RV32I program into instruction memory.
//  3. Provides a simple data memory model.
//  4. Runs the simulation for N cycles.
//  5. At the end, reads a few key register / memory values
//     and prints PASS / FAIL.
//
//  Inline CPU top
//  --------------
//  The testbench wraps a cpu_top module which ties together:
//    - Program Counter (PC)
//    - Instruction memory (imem)
//    - Register file (regfile)
//    - alu.v, control.v, imm_gen.v, dcache.v
//
//  Feel free to replace cpu_top with your own top-level.
// ============================================================

`timescale 1ns/1ps

// ============================================================
// Register file (32×32)
// ============================================================
module regfile (
    input  wire        clk,
    input  wire        we,
    input  wire [4:0]  rs1, rs2, rd,
    input  wire [31:0] wd,
    output wire [31:0] rd1, rd2
);
    reg [31:0] regs [1:31];
    integer i;
    initial for (i = 1; i < 32; i = i+1) regs[i] = 32'b0;

    assign rd1 = (rs1 == 5'd0) ? 32'b0 : regs[rs1];
    assign rd2 = (rs2 == 5'd0) ? 32'b0 : regs[rs2];

    always @(posedge clk)
        if (we && rd != 5'd0) regs[rd] <= wd;
endmodule

// ============================================================
// Instruction memory (sync read, word-addressed internally)
// ============================================================
module imem #(parameter DEPTH = 256) (
    input  wire [31:0] addr,
    output wire [31:0] instr
);
    reg [31:0] mem [0:DEPTH-1];
    integer i;
    initial begin
        for (i = 0; i < DEPTH; i = i+1) mem[i] = 32'h0000_0013; // NOP (ADDI x0,x0,0)

        // -------------------------------------------------------
        // Small RV32I test program
        // Expected final register values:
        //   x1  = 10
        //   x2  = 20
        //   x3  = 30   (ADD  x3, x1, x2)
        //   x4  = 10   (SUB  x4, x3, x2)
        //   x5  = 1    (SLT  x5, x1, x2)
        //   x6  = 30   (LW   x6, 0(x10) after SW x3,0(x10))
        //   x7  = 0x0F0F0F0F (AND / OR / XOR test)
        //   x8  = 0xFFFFFFFF
        //   x9  = 0xF0F0F0F0
        //   x10 = base addr 0x100
        // -------------------------------------------------------

        // addi x1, x0, 10
        mem[0]  = 32'h00A00093; // ADDI x1, x0, 10
        // addi x2, x0, 20
        mem[1]  = 32'h01400113; // ADDI x2, x0, 20
        // add  x3, x1, x2
        mem[2]  = 32'h002081B3; // ADD  x3, x1, x2
        // sub  x4, x3, x2
        mem[3]  = 32'h40218233; // SUB  x4, x3, x2
        // slt  x5, x1, x2
        mem[4]  = 32'h0020A2B3; // SLT  x5, x1, x2
        // lui  x10, 0x00100 (base = 0x100000? use small addr)
        // addi x10, x0, 0x100   (data base address = 256)
        mem[5]  = 32'h10000513; // ADDI x10, x0, 256  (0x100)
        // sw   x3, 0(x10)
        mem[6]  = 32'h00352023; // SW   x3, 0(x10)
        // lw   x6, 0(x10)
        mem[7]  = 32'h00052303; // LW   x6, 0(x10)
        // AND/OR/XOR test
        // addi x7, x0, 0x0F0  (cannot put 0x0F0F0F0F directly; build it)
        // lui  x7, 0x0F0F1 -> 0x0F0F1000
        // For simplicity, use a smaller pattern: 0x0F = 15
        mem[8]  = 32'h00F00393; // ADDI x7, x0, 15   (0x0F)
        // addi x8, x0, -1 (0xFFFFFFFF)
        mem[9]  = 32'hFFF00413; // ADDI x8, x0, -1
        // xor  x9, x8, x7   -> 0xFFFFFFFF ^ 0x0000000F = 0xFFFFFFF0
        mem[10] = 32'h007444B3; // XOR  x9, x8, x7
        // and  x11, x8, x7  -> 0x0F
        mem[11] = 32'h0074F5B3; // AND  x11, x8, x7
        // or   x12, x7, x8  -> 0xFFFFFFFF
        mem[12] = 32'h00836633; // OR   x12, x6, x8   (use x6=30 | x8=-1 = -1)
        // sll  x13, x1, x1  -> 10 << 10 = 10240
        mem[13] = 32'h00109693; // SLLI x13, x1, 1    -> 10<<1 = 20
        // srl  x14, x2, x1  -> (20 >> 1) (using SRLI)
        // srli x14, x2, 1
        mem[14] = 32'h00115713; // SRLI x14, x2, 1    -> 10
        // Branch test: beq x1, x14, +8 (skip next, go to mem[17])
        mem[15] = 32'h00E08463; // BEQ  x1, x14, +8
        // This should be skipped:
        mem[16] = 32'h00000013; // NOP  (should be skipped)
        // addi x15, x0, 99   (reached after branch)
        mem[17] = 32'h06300793; // ADDI x15, x0, 99
        // jal  x16, +4       (jump over next instruction)
        mem[18] = 32'h008008EF; // JAL  x16, +8       (skip mem[19])
        mem[19] = 32'h00000013; // NOP  (should be skipped)
        // addi x17, x0, 77   (reached after JAL)
        mem[20] = 32'h04D00893; // ADDI x17, x0, 77
        // infinite NOP loop (end of program)
        mem[21] = 32'h0000006F; // JAL  x0, 0  (infinite loop)
    end

    assign instr = mem[addr[31:2]]; // word-indexed
endmodule

// ============================================================
// Data memory stub (byte-addressable, 1 KB)
// Wraps dcache + backing array for testbench
// ============================================================
module dmem_stub (
    input  wire        clk,
    input  wire        rst_n,
    // CPU interface
    input  wire        req,
    input  wire        we,
    input  wire [31:0] addr,
    input  wire [31:0] wdata,
    input  wire [3:0]  wstrb,
    output wire [31:0] rdata,
    output wire        stall
);
    // Backing memory (1 KB)
    reg [7:0] backing [0:1023];
    integer i;
    initial for (i = 0; i < 1024; i = i+1) backing[i] = 8'h00;

    // Wires to/from dcache
    wire        mem_req_valid;
    wire [31:0] mem_req_addr;
    reg         mem_req_ready;
    reg         mem_rdata_valid;
    reg [127:0] mem_rdata;
    wire        mem_wvalid;
    wire [31:0] mem_waddr;
    wire [31:0] mem_wdata;
    wire [3:0]  mem_wstrb;

    dcache #(.CACHE_SIZE(1024), .LINE_SIZE(16), .ADDR_WIDTH(32)) u_dcache (
        .clk            (clk),
        .rst_n          (rst_n),
        .cpu_req        (req),
        .cpu_we         (we),
        .cpu_addr       (addr),
        .cpu_wdata      (wdata),
        .cpu_wstrb      (wstrb),
        .cpu_rdata      (rdata),
        .cpu_stall      (stall),
        .mem_req_valid  (mem_req_valid),
        .mem_req_addr   (mem_req_addr),
        .mem_req_ready  (mem_req_ready),
        .mem_rdata_valid(mem_rdata_valid),
        .mem_rdata      (mem_rdata),
        .mem_wvalid     (mem_wvalid),
        .mem_waddr      (mem_waddr),
        .mem_wdata      (mem_wdata),
        .mem_wstrb      (mem_wstrb)
    );

    // Simple 1-cycle memory model
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_req_ready  <= 1'b0;
            mem_rdata_valid<= 1'b0;
            mem_rdata      <= 128'b0;
        end else begin
            mem_req_ready   <= 1'b0;
            mem_rdata_valid <= 1'b0;

            // Handle write-through writes
            if (mem_wvalid) begin
                if (mem_wstrb[0]) backing[(mem_waddr & 10'h3FF) + 0] <= mem_wdata[ 7: 0];
                if (mem_wstrb[1]) backing[(mem_waddr & 10'h3FF) + 1] <= mem_wdata[15: 8];
                if (mem_wstrb[2]) backing[(mem_waddr & 10'h3FF) + 2] <= mem_wdata[23:16];
                if (mem_wstrb[3]) backing[(mem_waddr & 10'h3FF) + 3] <= mem_wdata[31:24];
            end

            // Handle refill requests (respond in 1 cycle)
            if (mem_req_valid && !mem_req_ready) begin
                mem_req_ready <= 1'b1;
            end
            if (mem_req_ready) begin
                mem_rdata_valid <= 1'b1;
                mem_rdata <= {
                    backing[(mem_req_addr & 10'h3FF)+15],
                    backing[(mem_req_addr & 10'h3FF)+14],
                    backing[(mem_req_addr & 10'h3FF)+13],
                    backing[(mem_req_addr & 10'h3FF)+12],
                    backing[(mem_req_addr & 10'h3FF)+11],
                    backing[(mem_req_addr & 10'h3FF)+10],
                    backing[(mem_req_addr & 10'h3FF)+ 9],
                    backing[(mem_req_addr & 10'h3FF)+ 8],
                    backing[(mem_req_addr & 10'h3FF)+ 7],
                    backing[(mem_req_addr & 10'h3FF)+ 6],
                    backing[(mem_req_addr & 10'h3FF)+ 5],
                    backing[(mem_req_addr & 10'h3FF)+ 4],
                    backing[(mem_req_addr & 10'h3FF)+ 3],
                    backing[(mem_req_addr & 10'h3FF)+ 2],
                    backing[(mem_req_addr & 10'h3FF)+ 1],
                    backing[(mem_req_addr & 10'h3FF)+ 0]
                };
            end
        end
    end
endmodule

// ============================================================
// CPU Top: single-cycle RISC-V RV32I
// ============================================================
module cpu_top (
    input wire clk,
    input wire rst_n
);
    // PC
    reg  [31:0] pc;
    wire [31:0] pc_next;

    // Instruction fields
    wire [31:0] instr;
    wire [6:0]  opcode = instr[6:0];
    wire [4:0]  rd     = instr[11:7];
    wire [2:0]  funct3 = instr[14:12];
    wire [4:0]  rs1    = instr[19:15];
    wire [4:0]  rs2    = instr[24:20];
    wire [6:0]  funct7 = instr[31:25];

    // Control signals
    wire        reg_write, alu_src, mem_read, mem_write;
    wire        mem_unsigned, branch, jal, jalr, lui, auipc;
    wire [3:0]  alu_ctrl;
    wire [1:0]  mem_size, wb_sel;

    // Register file outputs
    wire [31:0] rf_rd1, rf_rd2;

    // Immediate
    wire [31:0] imm;

    // ALU
    wire [31:0] alu_op_a, alu_op_b, alu_result;
    wire        alu_zero, alu_neg, alu_ov;

    // Data memory
    wire [31:0] dmem_rdata;
    wire        dmem_stall;
    wire [3:0]  mem_wstrb;

    // Write-back
    reg  [31:0] wb_data;

    // Branch / PC mux
    wire        branch_taken;
    wire [31:0] pc_plus4   = pc + 32'd4;
    wire [31:0] pc_branch  = pc + imm;
    wire [31:0] pc_jalr_t  = (rf_rd1 + imm) & ~32'h1;

    // ---- Instantiations ----

    imem u_imem (.addr(pc), .instr(instr));

    control u_ctrl (
        .opcode(opcode), .funct3(funct3), .funct7(funct7),
        .reg_write(reg_write), .alu_src(alu_src),
        .alu_ctrl(alu_ctrl),
        .mem_read(mem_read), .mem_write(mem_write),
        .mem_size(mem_size), .mem_unsigned(mem_unsigned),
        .wb_sel(wb_sel),
        .branch(branch), .jal(jal), .jalr(jalr),
        .lui(lui), .auipc(auipc)
    );

    regfile u_rf (
        .clk(clk), .we(reg_write & ~dmem_stall),
        .rs1(rs1), .rs2(rs2), .rd(rd),
        .wd(wb_data),
        .rd1(rf_rd1), .rd2(rf_rd2)
    );

    imm_gen u_immgen (.instr(instr), .imm_out(imm));

    // ALU operand A: PC for AUIPC / JAL, else RS1
    assign alu_op_a = (auipc || jal) ? pc : rf_rd1;
    // ALU operand B: immediate or RS2
    assign alu_op_b = alu_src ? imm : rf_rd2;

    alu u_alu (
        .operand_a(alu_op_a), .operand_b(alu_op_b),
        .alu_ctrl(alu_ctrl),
        .alu_result(alu_result),
        .zero(alu_zero), .negative(alu_neg), .overflow(alu_ov)
    );

    // Branch condition
    assign branch_taken =
        branch && (
            (funct3 == 3'b000 &&  alu_zero) || // BEQ
            (funct3 == 3'b001 && !alu_zero) || // BNE
            (funct3 == 3'b100 &&  alu_neg)  || // BLT
            (funct3 == 3'b101 && !alu_neg)  || // BGE
            (funct3 == 3'b110 &&  alu_zero) || // BLTU (simplified)
            (funct3 == 3'b111 && !alu_zero)    // BGEU (simplified)
        );

    // PC next
    assign pc_next = jalr        ? pc_jalr_t  :
                     (jal || branch_taken) ? pc_branch  :
                     pc_plus4;

    // Write-strobe for stores
    assign mem_wstrb =
        (mem_size == 2'b00) ? (4'b0001 << alu_result[1:0]) :
        (mem_size == 2'b01) ? (4'b0011 << alu_result[1:0]) :
        4'b1111;

    dmem_stub u_dmem (
        .clk(clk), .rst_n(rst_n),
        .req(mem_read | mem_write),
        .we(mem_write),
        .addr(alu_result),
        .wdata(rf_rd2),
        .wstrb(mem_wstrb),
        .rdata(dmem_rdata),
        .stall(dmem_stall)
    );

    // Write-back data mux
    always @(*) begin
        case (wb_sel)
            2'b00: wb_data = alu_result;
            2'b01: begin
                // Load sign/zero extension
                case (mem_size)
                    2'b00: wb_data = mem_unsigned ? {24'b0, dmem_rdata[7:0]}
                                                  : {{24{dmem_rdata[7]}}, dmem_rdata[7:0]};
                    2'b01: wb_data = mem_unsigned ? {16'b0, dmem_rdata[15:0]}
                                                  : {{16{dmem_rdata[15]}}, dmem_rdata[15:0]};
                    default: wb_data = dmem_rdata;
                endcase
            end
            2'b10: wb_data = pc_plus4;
            default: wb_data = alu_result;
        endcase
    end

    // PC register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)        pc <= 32'h0;
        else if (!dmem_stall) pc <= pc_next;
    end

endmodule

// ============================================================
// Testbench
// ============================================================
module tb_cpu;

    // Clock & reset
    reg clk, rst_n;

    // Clock: 10 ns period
    initial clk = 0;
    always #5 clk = ~clk;

    // DUT
    cpu_top dut (.clk(clk), .rst_n(rst_n));

    // Observe register file directly
    // (requires hierarchical reference — adjust path if needed)
    wire [31:0] x1  = dut.u_rf.regs[1];
    wire [31:0] x2  = dut.u_rf.regs[2];
    wire [31:0] x3  = dut.u_rf.regs[3];
    wire [31:0] x4  = dut.u_rf.regs[4];
    wire [31:0] x5  = dut.u_rf.regs[5];
    wire [31:0] x6  = dut.u_rf.regs[6];
    wire [31:0] x7  = dut.u_rf.regs[7];
    wire [31:0] x14 = dut.u_rf.regs[14];
    wire [31:0] x15 = dut.u_rf.regs[15];
    wire [31:0] x16 = dut.u_rf.regs[16];
    wire [31:0] x17 = dut.u_rf.regs[17];

    // VCD dump
    initial begin
        $dumpfile("tb_cpu.vcd");
        $dumpvars(0, tb_cpu);
    end

    integer fail_count;
    task check;
        input [127:0] name_str;
        input [31:0]  got;
        input [31:0]  expected;
        begin
            if (got === expected)
                $display("  PASS  %-10s  got=0x%08h", name_str, got);
            else begin
                $display("  FAIL  %-10s  got=0x%08h  expected=0x%08h",
                          name_str, got, expected);
                fail_count = fail_count + 1;
            end
        end
    endtask

    integer cycle;

    initial begin
        fail_count = 0;

        // ------- Reset -------
        rst_n = 0;
        repeat(3) @(posedge clk);
        rst_n = 1;

        // ------- Run for enough cycles -------
        repeat(80) @(posedge clk);

        // ------- Check results -------
        $display("\n========================================");
        $display(" RISC-V RV32I CPU Self-Check");
        $display("========================================");

        // Arithmetic
        check("x1",  x1,  32'd10);   // ADDI x1, x0, 10
        check("x2",  x2,  32'd20);   // ADDI x2, x0, 20
        check("x3",  x3,  32'd30);   // ADD  x3, x1, x2
        check("x4",  x4,  32'd10);   // SUB  x4, x3, x2
        check("x5",  x5,  32'd1);    // SLT  x5, x1, x2

        // Load/Store
        check("x6",  x6,  32'd30);   // LW   after SW x3 → mem → LW x6

        // Shift
        check("x14", x14, 32'd10);   // SRLI x14, x2, 1  (20>>1=10)

        // Branch (BEQ x1==x14 → skip NOP, land on ADDI x15,x0,99)
        check("x15", x15, 32'd99);

        // JAL (skip NOP, land on ADDI x17,x0,77)
        check("x17", x17, 32'd77);

        $display("========================================");
        if (fail_count == 0)
            $display(" ALL TESTS PASSED");
        else
            $display(" %0d TEST(S) FAILED", fail_count);
        $display("========================================\n");

        $finish;
    end

    // Cycle counter and timeout
    initial begin
        for (cycle = 0; cycle < 200; cycle = cycle + 1) begin
            @(posedge clk);
        end
        $display("TIMEOUT: simulation exceeded 200 cycles");
        $finish;
    end

    // Optional: print each cycle (uncomment for debug)
    // always @(posedge clk)
    //     $display("cyc=%0d pc=%h instr=%h", $time/10, dut.pc, dut.instr);

endmodule
