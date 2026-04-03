`timescale 1ns / 1ps
// ============================================================
// Main memory: 4 KB, serves both icache (128-bit line) and
// dcache (128-bit line).  5-cycle latency.
//
// The test program is encoded as 32-bit little-endian words
// and pre-loaded at address 0x000.
//
// Program logic (RISC-V RV32I):
//   Compute ADD, SUB, SLT, SLTI, SRA, LUI, AUIPC, BEQ, BNE,
//   JAL, JALR and store results to 0x0A0..0x0D0.
//   Then spin (infinite loop).
// ============================================================
module main_memory (
    input         clk, rst,
    // ICache port
    input         ireq,
    input  [31:0] iaddr,
    output reg [127:0] idata,
    output reg    iready,
    // DCache port
    input         dreq,
    input         dwrite,
    input  [31:0] daddr,
    input  [127:0] dwdata,
    input  [3:0]   dwe,
    output reg [127:0] drdata,
    output reg    dready
);
    // 4 KB = 1024 words
    reg [31:0] mem [0:1023];

    // ----------------------------------------------------------------
    // Test program
    // Registers used:
    //   x1  = 10
    //   x2  = 20
    //   x3  = result of ADD
    //   x4  = base address 0x0A0 (result area)
    //   x5  = scratch
    //   x6  = SLT(x1<x2)
    //   x7  = SLT(x2<x1)
    //   x8  = SLTI(x1<15)
    //   x9  = SLTI(x1<5)
    //   x28 = -80 (for SRA test)
    //   x29 = SRA result
    //   x30 = LUI result
    //   x31 = AUIPC result
    //
    // Memory layout (byte addresses):
    //   0x000 – 0x09C : instructions
    //   0x0A0 – 0x0D0 : result area (13 words)
    //
    // Assembled by hand; each entry is a 32-bit LE instruction word.
    // ----------------------------------------------------------------
    //
    // IMPORTANT: AUIPC test.
    //   The AUIPC instruction is at a known PC.  We place it at a fixed
    //   offset and compute the expected result accordingly.
    //   With the program below, AUIPC is at instruction index 10 →
    //   byte address 0x028 → 0x28 + 0x1000 = 0x1028.
    //   But the testbench expects 0x1054 (byte address 0x54 + 0x1000).
    //   We arrange the program so AUIPC sits at 0x054.
    //
    // Let's lay out the program carefully:
    //   [00] addi x1, x0, 10       // x1 = 10
    //   [04] addi x2, x0, 20       // x2 = 20
    //   [08] add  x3, x1, x2       // x3 = 30  (ADD test)
    //   [0C] sub  x5, x3, x1       // x5 = 20  (SUB test)
    //   [10] slt  x6, x1, x2       // x6 = 1   (SLT true)
    //   [14] slt  x7, x2, x1       // x7 = 0   (SLT false)
    //   [18] slti x8, x1, 15       // x8 = 1   (SLTI true)
    //   [1C] slti x9, x1, 5        // x9 = 0   (SLTI false)
    //   [20] addi x28,x0,-80       // x28= -80
    //   [24] srai x29,x28,3        // x29= -10 (SRA)
    //   [28] lui  x30,0xABCDE      // x30= 0xABCDE000 (LUI)
    //   [2C] lui  x4, 0            // x4 = 0 (prepare base)
    //   [30] addi x4, x4, 0xA0    // Wait — 0xA0 = 160, fits in 12-bit imm
    //        Actually: addi x4, x0, 0 then ori ... easier:
    //        lui x4, 0; addi x4,x4,0xA0  → but lui rd,0 = nop-ish
    //        Better: addi x4, x0, 160  (0xA0 decimal is 160, fits as 12-bit)
    //   Let's redo [2C]:
    //   [2C] addi x4, x0, 160      // x4 = 0xA0
    //   [30] sw   x3, 0(x4)        // M[0xA0] = ADD result (30)
    //   [34] sw   x5, 4(x4)        // M[0xA4] = SUB result (20)
    //   [38] sw   x6, 8(x4)        // M[0xA8] = SLT true   (1)
    //   [3C] sw   x7, 12(x4)       // M[0xAC] = SLT false  (0)
    //   [40] sw   x8, 16(x4)       // M[0xB0] = SLTI true  (1)
    //   [44] sw   x9, 20(x4)       // M[0xB4] = SLTI false (0)
    //   [48] sw   x29,24(x4)       // M[0xB8] = SRA (-10)
    //   [4C] sw   x30,28(x4)       // M[0xBC] = LUI
    //   [50] auipc x31,1           // x31 = PC(0x50) + 0x1000 = 0x1050
    //        Hmm, testbench expects 0x1054 for AUIPC at PC=0x54.
    //        Let's add a nop to push AUIPC to 0x54:
    //   [50] addi x0,x0,0          // NOP
    //   [54] auipc x31,1           // x31 = 0x54 + 0x1000 = 0x1054  ✓
    //   [58] sw   x31,32(x4)       // M[0xC0] = AUIPC (0x1054)
    //
    //   BEQ test: beq x1,x1, +8 (jump over nop, land on store 0xBB)
    //   [5C] addi x5, x0, 0xBB    // x5 = 0xBB (pre-load, branch skips store of 0x00)
    //   [60] beq  x1, x1, +8      // taken → skip [64], go to [68]
    //   [64] addi x5, x0, 0       // NOT executed
    //   [68] sw   x5, 36(x4)      // M[0xC4] = 0xBB  ✓
    //
    //   BNE test: bne x1,x2, +8
    //   [6C] addi x5, x0, 0xCC
    //   [70] bne  x1, x2, +8      // taken (1≠20) → skip [74], go to [78]
    //   [74] addi x5, x0, 0
    //   [78] sw   x5, 40(x4)      // M[0xC8] = 0xCC  ✓
    //
    //   JAL test: jal x10, +8     x10 = PC+4 = 0x84
    //             testbench expects JAL link = 0x80
    //             So jal must be at 0x7C → x10 = 0x80
    //   [7C] jal  x10, +8         // x10 = 0x80, jump to [84]
    //   [80] addi x0, x0, 0       // skipped
    //   [84] sw   x10, 44(x4)     // M[0xCC] = 0x80  ✓
    //
    //   JALR test: jalr x11, x10, 8
    //              x10 = 0x80 (from above), x10+8 = 0x88
    //              x11 = PC+4 = 0x8C + 4 = 0x90
    //              testbench expects JALR link = 0x90
    //   [88] jalr x11, x10, 8     // x11=0x8C, jump to 0x88 (0x80+8)
    //        Wait: JALR jumps to (rs1+imm)&~1 = (0x80+8)&~1 = 0x88
    //        But we're already at 0x88, that creates a loop!
    //        Fix: use a different register. Let's use x12 pointing ahead.
    //
    //   Better plan for JALR:
    //   [88] addi x12, x0, 0x98   // x12 = 0x98 (target of jalr)
    //   [8C] jalr x11, x12, 0     // x11 = 0x90, jump to 0x98
    //        testbench expects link = 0x90 = 0x8C+4  ✓
    //   [90] addi x0,x0,0         // NOT executed
    //   [94] addi x0,x0,0         // NOT executed
    //   [98] sw   x11, 48(x4)     // M[0xD0] = 0x90  ✓
    //
    //   [9C] jal x0, 0            // infinite loop (spin)
    // ----------------------------------------------------------------

    // Instruction encodings (RV32I, LE 32-bit words):
    //
    //   ADDI rd,rs1,imm  : imm[11:0] | rs1 | 000 | rd | 0010011
    //   ADD  rd,rs1,rs2  : 0000000 | rs2 | rs1 | 000 | rd | 0110011
    //   SUB  rd,rs1,rs2  : 0100000 | rs2 | rs1 | 000 | rd | 0110011
    //   SLT  rd,rs1,rs2  : 0000000 | rs2 | rs1 | 010 | rd | 0110011
    //   SLTI rd,rs1,imm  : imm[11:0] | rs1 | 010 | rd | 0010011
    //   SRAI rd,rs1,shamt: 0100000 | shamt | rs1 | 101 | rd | 0010011
    //   LUI  rd,imm      : imm[31:12] | rd | 0110111
    //   AUIPC rd,imm     : imm[31:12] | rd | 0010111
    //   SW   rs2,imm(rs1): imm[11:5] | rs2 | rs1 | 010 | imm[4:0] | 0100011
    //   BEQ  rs1,rs2,off : off[12|10:5] | rs2 | rs1 | 000 | off[4:1|11] | 1100011
    //   BNE  rs1,rs2,off : off[12|10:5] | rs2 | rs1 | 001 | off[4:1|11] | 1100011
    //   JAL  rd,off      : off[20|10:1|11|19:12] | rd | 1101111
    //   JALR rd,rs1,imm  : imm[11:0] | rs1 | 000 | rd | 1100111

    // Helper macro values (used inline in mem[] assignments):
    //   For readability, each line below is one 32-bit hex word.

    initial begin
        // Zero-fill
        begin : zero_fill
            integer j;
            for (j=0; j<1024; j=j+1) mem[j] = 32'h0;
        end

        //------------------------------------------------------------
        // Instruction memory (word-addressed: mem[addr/4])
        //------------------------------------------------------------

        // Instructions verified by Python encoder:
        mem[ 0] = 32'h00A00093;  // [00] addi x1,x0,10
        mem[ 1] = 32'h01400113;  // [04] addi x2,x0,20
        mem[ 2] = 32'h002081B3;  // [08] add x3,x1,x2
        mem[ 3] = 32'h401182B3;  // [0C] sub x5,x3,x1
        mem[ 4] = 32'h0020A333;  // [10] slt x6,x1,x2
        mem[ 5] = 32'h001123B3;  // [14] slt x7,x2,x1
        mem[ 6] = 32'h00F0A413;  // [18] slti x8,x1,15
        mem[ 7] = 32'h0050A493;  // [1C] slti x9,x1,5
        mem[ 8] = 32'hFB000E13;  // [20] addi x28,x0,-80
        mem[ 9] = 32'h403E5E93;  // [24] srai x29,x28,3
        mem[10] = 32'hABCDEF37;  // [28] lui x30,0xABCDE
        mem[11] = 32'h0A000213;  // [2C] addi x4,x0,160  (x4=0xA0)
        mem[12] = 32'h00322023;  // [30] sw x3,0(x4)    → M[0xA0]=ADD
        mem[13] = 32'h00522223;  // [34] sw x5,4(x4)    → M[0xA4]=SUB
        mem[14] = 32'h00622423;  // [38] sw x6,8(x4)    → M[0xA8]=SLT_T
        mem[15] = 32'h00722623;  // [3C] sw x7,12(x4)   → M[0xAC]=SLT_F
        mem[16] = 32'h00822823;  // [40] sw x8,16(x4)   → M[0xB0]=SLTI_T
        mem[17] = 32'h00922A23;  // [44] sw x9,20(x4)   → M[0xB4]=SLTI_F
        mem[18] = 32'h01D22C23;  // [48] sw x29,24(x4)  → M[0xB8]=SRA
        mem[19] = 32'h01E22E23;  // [4C] sw x30,28(x4)  → M[0xBC]=LUI
        mem[20] = 32'h00000013;  // [50] nop
        mem[21] = 32'h00001F97;  // [54] auipc x31,1  → x31=0x1054
        mem[22] = 32'h03F22023;  // [58] sw x31,32(x4)  → M[0xC0]=AUIPC
        mem[23] = 32'h0BB00293;  // [5C] addi x5,x0,0xBB
        mem[24] = 32'h00108463;  // [60] beq x1,x1,+8  (taken → skip [64])
        mem[25] = 32'h00000293;  // [64] addi x5,x0,0  (skipped)
        mem[26] = 32'h02522223;  // [68] sw x5,36(x4)  → M[0xC4]=BEQ(0xBB)
        mem[27] = 32'h0CC00293;  // [6C] addi x5,x0,0xCC
        mem[28] = 32'h00209463;  // [70] bne x1,x2,+8  (taken → skip [74])
        mem[29] = 32'h00000293;  // [74] addi x5,x0,0  (skipped)
        mem[30] = 32'h02522423;  // [78] sw x5,40(x4)  → M[0xC8]=BNE(0xCC)
        mem[31] = 32'h0080056F;  // [7C] jal x10,+8   x10=0x80 → jump to [84]
        mem[32] = 32'h00000013;  // [80] nop (skipped)
        mem[33] = 32'h02A22623;  // [84] sw x10,44(x4) → M[0xCC]=JAL(0x80)
        mem[34] = 32'h09800613;  // [88] addi x12,x0,0x98
        mem[35] = 32'h000605E7;  // [8C] jalr x11,x12,0  x11=0x90 → jump to 0x98
        mem[36] = 32'h00000013;  // [90] nop (skipped)
        mem[37] = 32'h00000013;  // [94] nop (skipped)
        mem[38] = 32'h02B22823;  // [98] sw x11,48(x4) → M[0xD0]=JALR(0x90)
        mem[39] = 32'h0000006F;  // [9C] jal x0,0 (infinite loop)

        // Result area 0x0A0..0x0D0 — pre-zero (already zeroed above)
    end

    // ----------------------------------------------------------------
    // Latency: 5-cycle pipeline for both ports
    // ----------------------------------------------------------------
    reg [2:0] icnt, dcnt;
    reg       iactive, dactive;
    reg [31:0] iaddr_r, daddr_r;
    reg        dwrite_r;
    reg [127:0] dwdata_r;
    reg [3:0]   dwe_r;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            icnt <= 0; dcnt <= 0;
            iactive <= 0; dactive <= 0;
            iready <= 0; dready <= 0;
            idata  <= 0; drdata <= 0;
        end else begin
            iready <= 0;
            dready <= 0;

            // Instruction port
            if (ireq && !iactive) begin
                iactive <= 1;
                icnt    <= 4;
                iaddr_r <= iaddr;
            end else if (iactive) begin
                if (icnt == 0) begin
                    iactive <= 0;
                    iready  <= 1;
                    idata   <= {mem[(iaddr_r>>2)+3], mem[(iaddr_r>>2)+2],
                                mem[(iaddr_r>>2)+1], mem[(iaddr_r>>2)+0]};
                end else begin
                    icnt <= icnt - 1;
                end
            end

            // Data port
            if (dreq && !dactive) begin
                dactive  <= 1;
                dcnt     <= 4;
                daddr_r  <= daddr;
                dwrite_r <= dwrite;
                dwdata_r <= dwdata;
                dwe_r    <= dwe;
            end else if (dactive) begin
                if (dcnt == 0) begin
                    dactive <= 0;
                    dready  <= 1;
                    if (dwrite_r) begin
                        if (dwe_r[0]) mem[(daddr_r>>2)+0] <= dwdata_r[31:0];
                        if (dwe_r[1]) mem[(daddr_r>>2)+1] <= dwdata_r[63:32];
                        if (dwe_r[2]) mem[(daddr_r>>2)+2] <= dwdata_r[95:64];
                        if (dwe_r[3]) mem[(daddr_r>>2)+3] <= dwdata_r[127:96];
                        drdata <= 128'h0;
                    end else begin
                        drdata <= {mem[(daddr_r>>2)+3], mem[(daddr_r>>2)+2],
                                   mem[(daddr_r>>2)+1], mem[(daddr_r>>2)+0]};
                    end
                end else begin
                    dcnt <= dcnt - 1;
                end
            end
        end
    end
endmodule
