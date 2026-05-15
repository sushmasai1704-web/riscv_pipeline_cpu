`timescale 1ns/1ps

module pipeline_cpu(
    input clk,
    input rst
);

// ─── Register File ────────────────────────────────────────────────
reg [31:0] regs [0:31];
integer ri;

// ─── Instruction Memory ───────────────────────────────────────────
reg [31:0] imem [0:63];
initial begin
    imem[0] = 32'h00A00093; // addi x1, x0, 10
    imem[1] = 32'h01400113; // addi x2, x0, 20
    imem[2] = 32'h01E00193; // addi x3, x0, 30
    imem[3] = 32'h00208233; // add  x4, x1, x2  -> 30
    imem[4] = 32'h004182B3; // add  x5, x3, x4  -> 60
    imem[5] = 32'h00402023; // sw   x4, 0(x0)   -> mem[0]=30
    imem[6] = 32'h0000006F; // jal  x0, 0       -> halt
    begin : fill
        integer k;
        for (k = 7; k < 64; k = k+1) imem[k] = 32'h00000013; // NOP
    end
    for (ri = 0; ri < 32; ri = ri+1) regs[ri] = 32'h0;
end

// ─── Data Memory ─────────────────────────────────────────────────
reg [31:0] dmem [0:255];
initial begin : dmem_init
    integer j;
    for (j = 0; j < 256; j = j+1) dmem[j] = 32'h0;
end

// ─── PC ──────────────────────────────────────────────────────────
reg [31:0] PC;

// ─── IF/ID ───────────────────────────────────────────────────────
reg [31:0] IF_ID_instr, IF_ID_PC;

// ─── ID/EX ───────────────────────────────────────────────────────
reg [31:0] ID_EX_PC, ID_EX_rs1_val, ID_EX_rs2_val, ID_EX_imm;
reg [4:0]  ID_EX_rs1, ID_EX_rs2, ID_EX_rd;
reg        ID_EX_alu_src;
reg        ID_EX_mem_read, ID_EX_mem_write;
reg        ID_EX_reg_write, ID_EX_mem_to_reg;
reg        ID_EX_branch, ID_EX_jal, ID_EX_jalr;
reg [2:0]  ID_EX_funct3;
reg        ID_EX_funct7_5;
reg        ID_EX_r_type;   // 1 = R-type, use funct3/funct7 for ALU op

// ─── EX/MEM ──────────────────────────────────────────────────────
reg [31:0] EX_MEM_alu_out, EX_MEM_rs2_val, EX_MEM_PC;
reg [4:0]  EX_MEM_rd;
reg        EX_MEM_mem_read, EX_MEM_mem_write;
reg        EX_MEM_reg_write, EX_MEM_mem_to_reg;
reg        EX_MEM_zero;

// ─── MEM/WB ──────────────────────────────────────────────────────
reg [31:0] MEM_WB_data, MEM_WB_alu_out;
reg [4:0]  MEM_WB_rd;
reg        MEM_WB_reg_write, MEM_WB_mem_to_reg;

// ─── Performance counters ────────────────────────────────────────
integer cycle_count, instr_count, stall_count, branch_count, mispredict_count;
wire mispredict = 1'b0;

// ─── Decode wires ────────────────────────────────────────────────
wire [6:0] dec_opcode   = IF_ID_instr[6:0];
wire [4:0] dec_rd       = IF_ID_instr[11:7];
wire [2:0] dec_funct3   = IF_ID_instr[14:12];
wire [4:0] dec_rs1      = IF_ID_instr[19:15];
wire [4:0] dec_rs2      = IF_ID_instr[24:20];
wire       dec_funct7_5 = IF_ID_instr[30];

// Control signals from control unit
wire [3:0] dec_alu_op;
wire       dec_alu_src, dec_mem_to_reg, dec_reg_write;
wire       dec_mem_read, dec_mem_write, dec_branch;
wire       dec_jal, dec_jalr, dec_lui, dec_auipc;
wire       dec_r_type = (dec_opcode == 7'b0110011);

control ctrl_inst (
    .opcode    (dec_opcode),
    .alu_op    (dec_alu_op),
    .alu_src   (dec_alu_src),
    .mem_to_reg(dec_mem_to_reg),
    .reg_write (dec_reg_write),
    .mem_read  (dec_mem_read),
    .mem_write (dec_mem_write),
    .branch    (dec_branch),
    .jal       (dec_jal),
    .jalr      (dec_jalr),
    .lui       (dec_lui),
    .auipc     (dec_auipc)
);

wire [31:0] dec_imm;
imm_gen immgen_inst (
    .instr(IF_ID_instr),
    .imm  (dec_imm)
);

// ─── ALU op selection (EX stage) ────────────────────────────────
// For R-type and I-type ALU, derive op from funct3/funct7
// For everything else (load/store/branch), use ADD
reg [3:0] alu_op_final;
always @(*) begin
    if (ID_EX_r_type || (ID_EX_alu_src && !ID_EX_mem_read && !ID_EX_mem_write && !ID_EX_branch)) begin
        // R-type or I-type ALU: decode from funct3
        case (ID_EX_funct3)
            3'b000: alu_op_final = (ID_EX_r_type && ID_EX_funct7_5) ? 4'b0001 : 4'b0000; // SUB or ADD/ADDI
            3'b001: alu_op_final = 4'b0010; // SLL
            3'b010: alu_op_final = 4'b0011; // SLT
            3'b011: alu_op_final = 4'b0100; // SLTU
            3'b100: alu_op_final = 4'b0101; // XOR
            3'b101: alu_op_final = ID_EX_funct7_5 ? 4'b0111 : 4'b0110; // SRA or SRL
            3'b110: alu_op_final = 4'b1000; // OR
            3'b111: alu_op_final = 4'b1001; // AND
            default: alu_op_final = 4'b0000;
        endcase
    end else begin
        alu_op_final = 4'b0000; // ADD for load/store/branch address calc
    end
end

// ─── Forwarding ──────────────────────────────────────────────────
wire [31:0] wb_data = MEM_WB_mem_to_reg ? MEM_WB_data : MEM_WB_alu_out;

wire fwd_a_ex  = EX_MEM_reg_write && (EX_MEM_rd != 0) && (EX_MEM_rd == ID_EX_rs1);
wire fwd_b_ex  = EX_MEM_reg_write && (EX_MEM_rd != 0) && (EX_MEM_rd == ID_EX_rs2);
wire fwd_a_mem = MEM_WB_reg_write && (MEM_WB_rd != 0) && (MEM_WB_rd == ID_EX_rs1) && !fwd_a_ex;
wire fwd_b_mem = MEM_WB_reg_write && (MEM_WB_rd != 0) && (MEM_WB_rd == ID_EX_rs2) && !fwd_b_ex;

reg [31:0] alu_a, alu_b_rs2, alu_b;
always @(*) begin
    if      (fwd_a_ex)  alu_a    = EX_MEM_alu_out;
    else if (fwd_a_mem) alu_a    = wb_data;
    else                alu_a    = ID_EX_rs1_val;

    if      (fwd_b_ex)  alu_b_rs2 = EX_MEM_alu_out;
    else if (fwd_b_mem) alu_b_rs2 = wb_data;
    else                alu_b_rs2 = ID_EX_rs2_val;

    alu_b = ID_EX_alu_src ? ID_EX_imm : alu_b_rs2;
end

// ─── ALU instance ────────────────────────────────────────────────
wire [31:0] alu_result;
wire        alu_zero;

alu alu_inst (
    .a       (alu_a),
    .b       (alu_b),
    .alu_op  (alu_op_final),
    .funct3  (ID_EX_funct3),
    .funct7_5(ID_EX_funct7_5),
    .result  (alu_result),
    .zero    (alu_zero)
);

// ─── Stall (load-use hazard) ─────────────────────────────────────
wire stall = ID_EX_mem_read &&
             (ID_EX_rd != 5'h0) &&
             ((ID_EX_rd == dec_rs1) || (ID_EX_rd == dec_rs2));

// ─── JAL target ──────────────────────────────────────────────────
wire        take_jal    = ID_EX_jal;
wire [31:0] jal_target  = ID_EX_PC + ID_EX_imm;

// ─── Pipeline registers (clocked) ────────────────────────────────
always @(posedge clk or posedge rst) begin
    if (rst) begin
        PC                <= 32'h0;
        IF_ID_instr       <= 32'h00000013;
        IF_ID_PC          <= 32'h0;
        ID_EX_rd          <= 0; ID_EX_rs1       <= 0; ID_EX_rs2     <= 0;
        ID_EX_rs1_val     <= 0; ID_EX_rs2_val   <= 0; ID_EX_imm     <= 0;
        ID_EX_alu_src     <= 0; ID_EX_mem_read  <= 0; ID_EX_mem_write<= 0;
        ID_EX_reg_write   <= 0; ID_EX_mem_to_reg<= 0;
        ID_EX_branch      <= 0; ID_EX_jal       <= 0; ID_EX_jalr    <= 0;
        ID_EX_funct3      <= 0; ID_EX_funct7_5  <= 0; ID_EX_r_type  <= 0;
        ID_EX_PC          <= 0;
        EX_MEM_alu_out    <= 0; EX_MEM_rs2_val  <= 0; EX_MEM_rd     <= 0;
        EX_MEM_mem_read   <= 0; EX_MEM_mem_write<= 0;
        EX_MEM_reg_write  <= 0; EX_MEM_mem_to_reg<= 0;
        EX_MEM_zero       <= 0; EX_MEM_PC       <= 0;
        MEM_WB_data       <= 0; MEM_WB_alu_out  <= 0; MEM_WB_rd     <= 0;
        MEM_WB_reg_write  <= 0; MEM_WB_mem_to_reg<= 0;
        cycle_count <= 0; instr_count <= 0; stall_count <= 0;
        branch_count <= 0; mispredict_count <= 0;
        for (ri = 0; ri < 32; ri = ri+1) regs[ri] = 32'h0;
    end else begin
        cycle_count <= cycle_count + 1;

        // ── WB ───────────────────────────────────────────────────
        if (MEM_WB_reg_write && MEM_WB_rd != 0) begin
            regs[MEM_WB_rd] <= MEM_WB_mem_to_reg ? MEM_WB_data : MEM_WB_alu_out;
            instr_count <= instr_count + 1;
        end

        // ── MEM/WB latch ─────────────────────────────────────────
        MEM_WB_alu_out    <= EX_MEM_alu_out;
        MEM_WB_rd         <= EX_MEM_rd;
        MEM_WB_reg_write  <= EX_MEM_reg_write;
        MEM_WB_mem_to_reg <= EX_MEM_mem_to_reg;
        if (EX_MEM_mem_read)
            MEM_WB_data <= dmem[EX_MEM_alu_out[9:2]];
        else
            MEM_WB_data <= 32'h0;
        if (EX_MEM_mem_write)
            dmem[EX_MEM_alu_out[9:2]] <= EX_MEM_rs2_val;

        // ── EX/MEM latch ─────────────────────────────────────────
        EX_MEM_alu_out    <= alu_result;
        EX_MEM_rs2_val    <= alu_b_rs2;
        EX_MEM_rd         <= ID_EX_rd;
        EX_MEM_mem_read   <= ID_EX_mem_read;
        EX_MEM_mem_write  <= ID_EX_mem_write;
        EX_MEM_reg_write  <= ID_EX_reg_write;
        EX_MEM_mem_to_reg <= ID_EX_mem_to_reg;
        EX_MEM_zero       <= alu_zero;
        EX_MEM_PC         <= ID_EX_PC;
        if (ID_EX_branch) branch_count <= branch_count + 1;

        // ── ID/EX latch ──────────────────────────────────────────
        if (stall) begin
            // Bubble
            ID_EX_reg_write  <= 0; ID_EX_mem_read  <= 0;
            ID_EX_mem_write  <= 0; ID_EX_branch    <= 0;
            ID_EX_jal        <= 0; ID_EX_jalr      <= 0;
            ID_EX_rd         <= 0;
            stall_count <= stall_count + 1;
        end else begin
            ID_EX_PC         <= IF_ID_PC;
            ID_EX_rs1_val    <= (dec_rs1 == 0) ? 32'h0 : regs[dec_rs1];
            ID_EX_rs2_val    <= (dec_rs2 == 0) ? 32'h0 : regs[dec_rs2];
            ID_EX_imm        <= dec_imm;
            ID_EX_rd         <= dec_rd;
            ID_EX_rs1        <= dec_rs1;
            ID_EX_rs2        <= dec_rs2;
            ID_EX_funct3     <= dec_funct3;
            ID_EX_funct7_5   <= dec_funct7_5;
            ID_EX_r_type     <= dec_r_type;
            ID_EX_alu_src    <= dec_alu_src;
            ID_EX_mem_read   <= dec_mem_read;
            ID_EX_mem_write  <= dec_mem_write;
            ID_EX_reg_write  <= dec_reg_write;
            ID_EX_mem_to_reg <= dec_mem_to_reg;
            ID_EX_branch     <= dec_branch;
            ID_EX_jal        <= dec_jal;
            ID_EX_jalr       <= dec_jalr;
        end

        // ── IF/ID latch ──────────────────────────────────────────
        if (!stall) begin
            if (take_jal) begin
                IF_ID_instr <= 32'h00000013; // flush
                IF_ID_PC    <= jal_target;
                PC          <= jal_target + 4;
            end else begin
                IF_ID_instr <= imem[PC[7:2]];
                IF_ID_PC    <= PC;
                PC          <= PC + 4;
            end
        end
    end
end

endmodule
