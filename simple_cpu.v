`timescale 1ns/1ps
module simple_cpu(
    input clk,
    input rst
);
    reg [31:0] PC;
    reg [31:0] regs[0:31];
    reg [31:0] instr_mem[0:31];
    integer i;

    // ================== Pipeline registers ==================
    reg [31:0] IF_ID_instr, IF_ID_PC;

    reg [4:0]  ID_EX_rd;
    reg [31:0] ID_EX_PC;
    reg        ID_EX_jal;
    reg        ID_EX_alu_src;
    reg [31:0] ID_EX_rs1_val, ID_EX_rs2_val;
    reg [31:0] ID_EX_imm;
    reg [31:0] ID_EX_jal_target;  // FIX Bug 1: carry JAL branch target

    reg [4:0]  EX_rd;
    reg [31:0] EX_out;
    reg        EX_jal;
    reg [31:0] EX_jal_target;

    reg [4:0]  MEM_rd;
    reg [31:0] MEM_out;

    reg [4:0]  WB_rd;
    reg [31:0] WB_data;

    // ================== Combinational decode in ID ==================

    wire [6:0] id_opcode = IF_ID_instr[6:0];

    wire [31:0] id_imm =
        (id_opcode == 7'b0010011 || id_opcode == 7'b0000011)
            ? {{20{IF_ID_instr[31]}}, IF_ID_instr[31:20]}
        : (id_opcode == 7'b0100011)
            ? {{20{IF_ID_instr[31]}}, IF_ID_instr[31:25], IF_ID_instr[11:7]}
        : (id_opcode == 7'b1100011)
            ? {{19{IF_ID_instr[31]}}, IF_ID_instr[31], IF_ID_instr[7],
               IF_ID_instr[30:25], IF_ID_instr[11:8], 1'b0}
        : (id_opcode == 7'b1101111)
            ? {{11{IF_ID_instr[31]}}, IF_ID_instr[31], IF_ID_instr[19:12],
               IF_ID_instr[20], IF_ID_instr[30:21], 1'b0}
        : 32'b0;

    wire id_alu_src = (id_opcode == 7'b0010011) |
                      (id_opcode == 7'b0000011) |
                      (id_opcode == 7'b0100011);

    // ================== Forwarding mux ==================
    wire [31:0] rs1_fwd =
        (IF_ID_instr[19:15] != 5'b0 && IF_ID_instr[19:15] == EX_rd)  ? EX_out  :
        (IF_ID_instr[19:15] != 5'b0 && IF_ID_instr[19:15] == MEM_rd) ? MEM_out :
        regs[IF_ID_instr[19:15]];

    wire [31:0] rs2_fwd =
        (IF_ID_instr[24:20] != 5'b0 && IF_ID_instr[24:20] == EX_rd)  ? EX_out  :
        (IF_ID_instr[24:20] != 5'b0 && IF_ID_instr[24:20] == MEM_rd) ? MEM_out :
        regs[IF_ID_instr[24:20]];

    // ================== Initialization ==================
    initial begin
        PC = 0;
        for (i = 0; i < 32; i = i + 1) regs[i] = 0;
        for (i = 0; i < 32; i = i + 1) instr_mem[i] = 0;

        // [0] JAL x5, +8    -> x5 = 4,  PC jumps to 8
        // [2] ADDI x6,x5,6  -> x6 = 4+6 = 10
        // [3] ADD x8,x6,x6  -> x8 = 20
        instr_mem[0] = 32'b00000000100000000000001011101111; // JAL  x5, +8
        instr_mem[2] = 32'b00000000011000101000001100010011; // ADDI x6, x5, 6
        instr_mem[3] = 32'b00000000011000110000010000110011; // ADD  x8, x6, x6

        IF_ID_instr = 0; IF_ID_PC = 0;
        ID_EX_rd = 0; ID_EX_PC = 0; ID_EX_jal = 0;
        ID_EX_alu_src = 0; ID_EX_rs1_val = 0; ID_EX_rs2_val = 0;
        ID_EX_imm = 0; ID_EX_jal_target = 0;
        EX_rd = 0; EX_out = 0; EX_jal = 0; EX_jal_target = 0;
        MEM_rd = 0; MEM_out = 0;
        WB_rd = 0; WB_data = 0;
    end

    // ================== Pipeline clocked logic ==================
    always @(posedge clk) begin
        if (rst) begin
            PC <= 0;
            IF_ID_instr <= 0; IF_ID_PC <= 0;
            ID_EX_rd <= 0; ID_EX_PC <= 0; ID_EX_jal <= 0;
            ID_EX_alu_src <= 0; ID_EX_rs1_val <= 0; ID_EX_rs2_val <= 0;
            ID_EX_imm <= 0; ID_EX_jal_target <= 0;
            EX_rd <= 0; EX_out <= 0; EX_jal <= 0; EX_jal_target <= 0;
            MEM_rd <= 0; MEM_out <= 0;
            WB_rd <= 0; WB_data <= 0;
            for (i = 0; i < 32; i = i + 1) regs[i] = 0;
        end
        else begin
            // ---- WB ----
            if (WB_rd != 0)
                regs[WB_rd] <= WB_data;

            // ---- MEM -> WB ----
            WB_rd   <= MEM_rd;
            WB_data <= MEM_out;

            // ---- EX -> MEM ----
            MEM_rd  <= EX_rd;
            MEM_out <= EX_out;

            // ---- ID -> EX ----
            EX_rd         <= ID_EX_rd;
            EX_jal        <= ID_EX_jal;
            EX_jal_target <= ID_EX_jal_target;
            // FIX Bug 2: mux between rs2 and immediate
            EX_out        <= ID_EX_jal     ? ID_EX_PC + 4               // link addr
                           : ID_EX_alu_src ? ID_EX_rs1_val + ID_EX_imm  // I-type
                           :                 ID_EX_rs1_val + ID_EX_rs2_val; // R-type

            // ---- IF -> ID ----
            ID_EX_rd         <= IF_ID_instr[11:7];
            ID_EX_PC         <= IF_ID_PC;
            ID_EX_jal        <= (id_opcode == 7'b1101111);
            ID_EX_alu_src    <= id_alu_src;
            ID_EX_rs1_val    <= rs1_fwd;
            ID_EX_rs2_val    <= rs2_fwd;
            ID_EX_imm        <= id_imm;
            // FIX Bug 1: compute jump target in ID using decoded immediate
            ID_EX_jal_target <= IF_ID_PC + id_imm;

            // ---- IF ----
            IF_ID_instr <= instr_mem[PC >> 2];
            IF_ID_PC    <= PC;

            // ---- PC update ----
            // FIX Bug 1: use the pipelined target instead of EX_PC + 8
            PC <= EX_jal ? EX_jal_target : PC + 4;
        end
    end

    // ================== Monitor ==================
    always @(posedge clk) begin
        if (!rst)
            $display("PC=%0d  x5=%0d  x6=%0d  x8=%0d", PC, regs[5], regs[6], regs[8]);
    end

endmodule
