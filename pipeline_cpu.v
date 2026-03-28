`timescale 1ns / 1ps

// ============================================================
// pipeline_cpu.v — 5-Stage Pipelined RISC-V RV32I CPU
//
// Fixes vs original:
//  1. JAL/branch FLUSH of IF_ID register (was missing → PC=40 bug)
//  2. JAL writes PC+4 to rd (not ALU result)
//  3. Full RV32I ALU op decoding in EX stage (funct3/funct7)
//  4. WB forwarding uses wb_data (covers load→use via MEM_WB)
//  5. Load-use stall inserts bubble into ID_EX correctly
//  6. CPI performance counter added
// ============================================================
module pipeline_cpu(
    input clk,
    input rst
);

// ============================================================
// IF STAGE — Instruction Fetch
// ============================================================
    reg  [31:0] PC;
    wire [31:0] pc_plus4;
    wire [31:0] instr;

    reg [31:0] instr_mem [0:255];
    initial $readmemh("program.hex", instr_mem);

    assign pc_plus4 = PC + 4;
    assign instr    = instr_mem[PC[9:2]];

    // Stall and flush control wires (declared early, driven later)
    wire stall;        // load-use hazard stall
    wire flush_if_id; // flush on taken branch or JAL

    always @(posedge clk or posedge rst) begin
        if (rst)
            PC <= 32'h0;
        else if (!stall)
            PC <= pc_next;
    end

// ============================================================
// IF/ID PIPELINE REGISTER
// ============================================================
    reg [31:0] IF_ID_pc, IF_ID_instr;

    wire [6:0] IF_ID_opcode = IF_ID_instr[6:0];
    wire [4:0] IF_ID_rs1    = IF_ID_instr[19:15];
    wire [4:0] IF_ID_rs2    = IF_ID_instr[24:20];
    wire [4:0] IF_ID_rd     = IF_ID_instr[11:7];

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            IF_ID_pc    <= 32'h0;
            IF_ID_instr <= 32'h00000013; // NOP
        end else if (flush_if_id) begin
            // FIX 1: flush the wrong instruction fetched after JAL/branch
            IF_ID_pc    <= 32'h0;
            IF_ID_instr <= 32'h00000013; // NOP
        end else if (!stall) begin
            IF_ID_pc    <= PC;
            IF_ID_instr <= instr;
        end
        // if stall: hold current IF_ID (do nothing)
    end

// ============================================================
// ID STAGE — Instruction Decode + Register Read
// ============================================================
    wire [31:0] imm_out;
    wire [3:0]  ctrl_alu_op;
    wire        ctrl_alu_src, ctrl_mem_to_reg, ctrl_reg_write;
    wire        ctrl_mem_read, ctrl_mem_write, ctrl_branch;
    wire        ctrl_jal, ctrl_jalr;

    control ctrl_inst(
        .opcode    (IF_ID_opcode),
        .alu_op    (ctrl_alu_op),
        .alu_src   (ctrl_alu_src),
        .mem_to_reg(ctrl_mem_to_reg),
        .reg_write (ctrl_reg_write),
        .mem_read  (ctrl_mem_read),
        .mem_write (ctrl_mem_write),
        .branch    (ctrl_branch),
        .jal       (ctrl_jal),
        .jalr      (ctrl_jalr)
    );

    imm_gen imm_gen_inst(
        .instr(IF_ID_instr),
        .imm  (imm_out)
    );

    // Register File
    reg  [31:0] regs [0:31];
    wire [31:0] reg_rdata1, reg_rdata2;

    assign reg_rdata1 = (IF_ID_rs1 == 0) ? 32'h0 : regs[IF_ID_rs1];
    assign reg_rdata2 = (IF_ID_rs2 == 0) ? 32'h0 : regs[IF_ID_rs2];

    integer k;
    initial begin
        for (k = 0; k < 32; k = k + 1) regs[k] = 32'h0;
    end

// ============================================================
// WB STAGE signals (declared here, used in WB + forwarding)
// ============================================================
    reg  [31:0] reg_wdata_wb;
    reg  [4:0]  reg_waddr_wb;
    reg         reg_write_wb;

    always @(posedge clk) begin
        if (reg_write_wb && (reg_waddr_wb != 5'h0))
            regs[reg_waddr_wb] <= reg_wdata_wb;
    end

// ============================================================
// HAZARD DETECTION — Load-Use Stall
// ============================================================
    // Stall when EX stage has a load AND destination matches ID source
    assign stall = (ID_EX_mem_read &&
                    (ID_EX_rd != 5'h0) &&
                    ((ID_EX_rd == IF_ID_rs1) || (ID_EX_rd == IF_ID_rs2)));

    // FIX 1: Flush IF/ID when JAL or taken branch resolves in EX stage
    wire branch_taken = ID_EX_branch && alu_zero;
    assign flush_if_id = (ID_EX_jal || branch_taken || ID_EX_jalr);

// ============================================================
// ID/EX PIPELINE REGISTER
// ============================================================
    reg [31:0] ID_EX_pc, ID_EX_reg_rdata1, ID_EX_reg_rdata2, ID_EX_imm;
    reg [4:0]  ID_EX_rs1, ID_EX_rs2, ID_EX_rd;
    reg [3:0]  ID_EX_alu_op;
    reg [2:0]  ID_EX_funct3;
    reg        ID_EX_funct7_5;
    reg        ID_EX_alu_src, ID_EX_mem_to_reg, ID_EX_reg_write;
    reg        ID_EX_mem_read, ID_EX_mem_write, ID_EX_branch;
    reg        ID_EX_jal, ID_EX_jalr;

    always @(posedge clk or posedge rst) begin
        if (rst || stall) begin
            // Insert NOP bubble on stall
            ID_EX_pc          <= 32'h0;
            ID_EX_reg_rdata1  <= 32'h0;
            ID_EX_reg_rdata2  <= 32'h0;
            ID_EX_imm         <= 32'h0;
            ID_EX_rs1         <= 5'h0;
            ID_EX_rs2         <= 5'h0;
            ID_EX_rd          <= 5'h0;
            ID_EX_alu_op      <= 4'h0;
            ID_EX_funct3      <= 3'h0;
            ID_EX_funct7_5    <= 1'b0;
            ID_EX_alu_src     <= 1'b0;
            ID_EX_mem_to_reg  <= 1'b0;
            ID_EX_reg_write   <= 1'b0;
            ID_EX_mem_read    <= 1'b0;
            ID_EX_mem_write   <= 1'b0;
            ID_EX_branch      <= 1'b0;
            ID_EX_jal         <= 1'b0;
            ID_EX_jalr        <= 1'b0;
        end else begin
            ID_EX_pc          <= IF_ID_pc;
            ID_EX_reg_rdata1  <= reg_rdata1;
            ID_EX_reg_rdata2  <= reg_rdata2;
            ID_EX_imm         <= imm_out;
            ID_EX_rs1         <= IF_ID_rs1;
            ID_EX_rs2         <= IF_ID_rs2;
            ID_EX_rd          <= IF_ID_rd;
            ID_EX_alu_op      <= ctrl_alu_op;
            ID_EX_funct3      <= IF_ID_instr[14:12];
            ID_EX_funct7_5    <= IF_ID_instr[30];
            ID_EX_alu_src     <= ctrl_alu_src;
            ID_EX_mem_to_reg  <= ctrl_mem_to_reg;
            ID_EX_reg_write   <= ctrl_reg_write;
            ID_EX_mem_read    <= ctrl_mem_read;
            ID_EX_mem_write   <= ctrl_mem_write;
            ID_EX_branch      <= ctrl_branch;
            ID_EX_jal         <= ctrl_jal;
            ID_EX_jalr        <= ctrl_jalr;
        end
    end

// ============================================================
// EX STAGE — Execute
// ============================================================

    // FIX 3: Decode actual ALU operation from funct3/funct7 in EX
    reg [3:0] ex_alu_op;
    always @(*) begin
        ex_alu_op = ID_EX_alu_op; // default from control
        case (IF_ID_opcode) // use ID_EX opcode context via funct3
            default: begin
                // R-type and I-type ALU: decode from funct3
                case (ID_EX_funct3)
                    3'b000: ex_alu_op = (ID_EX_funct7_5 && !ID_EX_alu_src)
                                         ? 4'b0001  // SUB (R-type only)
                                         : 4'b0000; // ADD / ADDI
                    3'b001: ex_alu_op = 4'b0010; // SLL / SLLI
                    3'b010: ex_alu_op = 4'b0011; // SLT / SLTI
                    3'b011: ex_alu_op = 4'b0100; // SLTU / SLTIU
                    3'b100: ex_alu_op = 4'b0101; // XOR / XORI
                    3'b101: ex_alu_op = ID_EX_funct7_5
                                         ? 4'b0111  // SRA / SRAI
                                         : 4'b0110; // SRL / SRLI
                    3'b110: ex_alu_op = 4'b1000; // OR  / ORI
                    3'b111: ex_alu_op = 4'b1001; // AND / ANDI
                    default: ex_alu_op = 4'b0000;
                endcase
            end
        endcase
    end

    // Forwarding Unit
    // FIX 4: Forward wb_data (not just alu_result) from MEM/WB stage
    wire [31:0] wb_data = (MEM_WB_mem_to_reg) ? MEM_WB_mem_data : MEM_WB_alu_result;

    wire [1:0] forward_a_sel, forward_b_sel;
    assign forward_a_sel =
        (EX_MEM_reg_write && (EX_MEM_rd != 0) && (EX_MEM_rd == ID_EX_rs1)) ? 2'b10 :
        (MEM_WB_reg_write && (MEM_WB_rd != 0) && (MEM_WB_rd == ID_EX_rs1)) ? 2'b01 :
        2'b00;

    assign forward_b_sel =
        (EX_MEM_reg_write && (EX_MEM_rd != 0) && (EX_MEM_rd == ID_EX_rs2)) ? 2'b10 :
        (MEM_WB_reg_write && (MEM_WB_rd != 0) && (MEM_WB_rd == ID_EX_rs2)) ? 2'b01 :
        2'b00;

    wire [31:0] forward_a_out, forward_b_out;
    assign forward_a_out =
        (forward_a_sel == 2'b10) ? EX_MEM_alu_result :
        (forward_a_sel == 2'b01) ? wb_data :           // FIX 4
        ID_EX_reg_rdata1;

    assign forward_b_out =
        (forward_b_sel == 2'b10) ? EX_MEM_alu_result :
        (forward_b_sel == 2'b01) ? wb_data :           // FIX 4
        ID_EX_reg_rdata2;

    wire [31:0] alu_in_a = forward_a_out;
    wire [31:0] alu_in_b = ID_EX_alu_src ? ID_EX_imm : forward_b_out;

    wire [31:0] alu_result;
    wire        alu_zero;

    alu alu_inst(
        .a       (alu_in_a),
        .b       (alu_in_b),
        .alu_op  (ex_alu_op),
        .funct3  (ID_EX_funct3),
        .funct7_5(ID_EX_funct7_5),
        .result  (alu_result),
        .zero    (alu_zero)
    );

    // Branch / Jump target
    wire [31:0] branch_target = ID_EX_pc + ID_EX_imm;
    wire [31:0] jal_target    = ID_EX_pc + ID_EX_imm;
    wire [31:0] jalr_target   = {alu_result[31:1], 1'b0};

    // FIX 2: JAL writes PC+4 to rd — use pc_plus4_ex for that
    wire [31:0] pc_plus4_ex   = ID_EX_pc + 4;

    wire [31:0] pc_next =
        ID_EX_jal              ? jal_target    :
        (ID_EX_branch && alu_zero) ? branch_target :
        ID_EX_jalr             ? jalr_target   :
        pc_plus4;

// ============================================================
// EX/MEM PIPELINE REGISTER
// ============================================================
    reg [31:0] EX_MEM_alu_result, EX_MEM_reg_rdata2;
    reg [31:0] EX_MEM_pc_plus4;   // for JAL return address
    reg [4:0]  EX_MEM_rd;
    reg        EX_MEM_mem_to_reg, EX_MEM_reg_write;
    reg        EX_MEM_mem_read,   EX_MEM_mem_write;
    reg        EX_MEM_jal;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            EX_MEM_alu_result  <= 32'h0;
            EX_MEM_reg_rdata2  <= 32'h0;
            EX_MEM_pc_plus4    <= 32'h0;
            EX_MEM_rd          <= 5'h0;
            EX_MEM_mem_to_reg  <= 1'b0;
            EX_MEM_reg_write   <= 1'b0;
            EX_MEM_mem_read    <= 1'b0;
            EX_MEM_mem_write   <= 1'b0;
            EX_MEM_jal         <= 1'b0;
        end else begin
            EX_MEM_alu_result  <= alu_result;
            EX_MEM_reg_rdata2  <= forward_b_out;
            EX_MEM_pc_plus4    <= pc_plus4_ex;  // FIX 2
            EX_MEM_rd          <= ID_EX_rd;
            EX_MEM_mem_to_reg  <= ID_EX_mem_to_reg;
            EX_MEM_reg_write   <= ID_EX_reg_write;
            EX_MEM_mem_read    <= ID_EX_mem_read;
            EX_MEM_mem_write   <= ID_EX_mem_write;
            EX_MEM_jal         <= ID_EX_jal;
        end
    end

// ============================================================
// MEM STAGE — Memory Access
// ============================================================
    reg  [31:0] data_mem [0:255];
    wire [31:0] mem_read_data;

    assign mem_read_data = data_mem[EX_MEM_alu_result[9:2]];

    always @(posedge clk) begin
        if (EX_MEM_mem_write)
            data_mem[EX_MEM_alu_result[9:2]] <= EX_MEM_reg_rdata2;
    end

// ============================================================
// MEM/WB PIPELINE REGISTER
// ============================================================
    reg [31:0] MEM_WB_alu_result, MEM_WB_mem_data;
    reg [31:0] MEM_WB_pc_plus4;
    reg [4:0]  MEM_WB_rd;
    reg        MEM_WB_mem_to_reg, MEM_WB_reg_write;
    reg        MEM_WB_jal;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            MEM_WB_alu_result <= 32'h0;
            MEM_WB_mem_data   <= 32'h0;
            MEM_WB_pc_plus4   <= 32'h0;
            MEM_WB_rd         <= 5'h0;
            MEM_WB_mem_to_reg <= 1'b0;
            MEM_WB_reg_write  <= 1'b0;
            MEM_WB_jal        <= 1'b0;
        end else begin
            MEM_WB_alu_result <= EX_MEM_alu_result;
            MEM_WB_mem_data   <= mem_read_data;
            MEM_WB_pc_plus4   <= EX_MEM_pc_plus4;
            MEM_WB_rd         <= EX_MEM_rd;
            MEM_WB_mem_to_reg <= EX_MEM_mem_to_reg;
            MEM_WB_reg_write  <= EX_MEM_reg_write;
            MEM_WB_jal        <= EX_MEM_jal;
        end
    end

// ============================================================
// WB STAGE — Write Back
// FIX 2: JAL writes PC+4 (return address), not ALU result
// ============================================================
    always @(*) begin
        if (MEM_WB_jal)
            reg_wdata_wb = MEM_WB_pc_plus4;         // JAL: return address
        else if (MEM_WB_mem_to_reg)
            reg_wdata_wb = MEM_WB_mem_data;          // Load
        else
            reg_wdata_wb = MEM_WB_alu_result;        // ALU result
        reg_waddr_wb = MEM_WB_rd;
        reg_write_wb = MEM_WB_reg_write;
    end

// ============================================================
// CPI PERFORMANCE COUNTER (Fix 5 — new addition)
// ============================================================
    reg [31:0] cycle_count;
    reg [31:0] instr_count;
    reg [31:0] stall_count;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            cycle_count <= 32'h0;
            instr_count <= 32'h0;
            stall_count <= 32'h0;
        end else begin
            cycle_count <= cycle_count + 1;
            if (stall)
                stall_count <= stall_count + 1;
            // Count instruction when it leaves ID stage (not a bubble)
            if (!stall && (IF_ID_instr != 32'h00000013) && (IF_ID_instr != 32'h0))
                instr_count <= instr_count + 1;
        end
    end

endmodule
