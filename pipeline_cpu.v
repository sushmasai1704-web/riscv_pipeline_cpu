`timescale 1ns / 1ps

module pipeline_cpu(
    input clk,
    input rst
);

    // ============================================================
    // SIGNAL DECLARATIONS
    // ============================================================

    // Predictor interface
    wire predict_taken;
    wire [31:0] predict_target;
    wire predict_valid;
    wire [31:0] ex_pc;
    wire        ex_branch;
    wire        ex_taken;
    wire [31:0] ex_target;
    wire        ex_valid;

    // IF Stage
    reg  [31:0] PC;
    wire [31:0] pc_plus4;
    wire [31:0] instr;
    wire [31:0] pc_next;
    wire        stall;
    wire        flush_if_id;

    // ID Stage
    wire [6:0] IF_ID_opcode;
    wire [4:0] IF_ID_rs1, IF_ID_rs2, IF_ID_rd;
    wire [31:0] IF_ID_pc, IF_ID_instr;
    wire        IF_ID_predict_taken;
    wire [31:0] IF_ID_predict_target;

    // EX Stage
    wire [31:0] ID_EX_pc;
    wire [31:0] ID_EX_reg_rdata1, ID_EX_reg_rdata2, ID_EX_imm;
    wire [4:0]  ID_EX_rs1, ID_EX_rs2, ID_EX_rd;
    wire        ID_EX_alu_src, ID_EX_mem_to_reg, ID_EX_reg_write;
    wire        ID_EX_mem_read, ID_EX_mem_write, ID_EX_branch;
    wire        ID_EX_jal, ID_EX_jalr;
    wire        ID_EX_lui, ID_EX_auipc;
    wire        ID_EX_predict_taken;
    wire [31:0] ID_EX_predict_target;
    wire [2:0]  ID_EX_funct3;
    wire        ID_EX_funct7_5;
    wire [3:0]  ID_EX_alu_op;

    // EX/MEM Stage
    wire [31:0] EX_MEM_alu_result;
    wire        EX_MEM_reg_write;
    wire [4:0]  EX_MEM_rd;
    wire        EX_MEM_mem_to_reg;
    wire [31:0] wb_data;
    wire [1:0]  forward_a_sel, forward_b_sel;
    wire [31:0] forward_a_out, forward_b_out;
    wire [31:0] alu_in_a, alu_in_b;
    wire [31:0] alu_result;
    wire        alu_zero;
    wire [31:0] branch_target, jal_target, jalr_target, pc_plus4_ex;
    wire        branch_taken_ex;
    wire [31:0] actual_target;
    wire        mispredict;

    // MEM/WB Stage
    wire [31:0] MEM_WB_alu_result, MEM_WB_mem_data;
    wire        MEM_WB_mem_to_reg;
    wire        MEM_WB_reg_write;
    wire [4:0]  MEM_WB_rd;
    wire        MEM_WB_jal;
    wire [31:0] MEM_WB_pc_plus4;
    wire        MEM_WB_mem_write;

    // ============================================================
    // BRANCH PREDICTOR
    // ============================================================
    branch_predictor #(
        .INDEX_BITS(8)
    ) bp (
        .clk(clk),
        .rst_n(!rst),
        .pc(PC),
        .predict_req(1'b1),
        .predict_taken(predict_taken),
        .predict_target(predict_target),
        .predict_valid(predict_valid),
        .ex_pc(ex_pc),
        .ex_branch(ex_branch),
        .ex_taken(ex_taken),
        .ex_target(ex_target),
        .ex_valid(ex_valid)
    );

    // ============================================================
    // IF STAGE
    // ============================================================
    assign pc_plus4 = PC + 4;

    wire        icache_hit;
    wire [31:0] icache_rdata;
    wire        icache_mem_req;
    wire [31:0] icache_mem_addr;
    wire [127:0] imem_rdata;
    wire         imem_iready;
    wire         icache_stall;

    icache icache_inst(
        .clk      (clk),
        .rst      (rst),
        .cpu_addr (PC),
        .cpu_rdata(icache_rdata),
        .cpu_hit  (icache_hit),
        .cpu_req  (1'b1),
        .mem_req  (icache_mem_req),
        .mem_addr (icache_mem_addr),
        .mem_rdata(imem_rdata),
        .mem_ready(imem_iready)
    );

    assign instr        = icache_hit ? icache_rdata : 32'h00000013;
    assign icache_stall = !icache_hit;

    assign mispredict = (ID_EX_branch || ID_EX_jal || ID_EX_jalr) &&
                        (ID_EX_predict_taken != branch_taken_ex);

    assign pc_next =
        mispredict                        ? actual_target  :
        (predict_valid && predict_taken)  ? predict_target :
        pc_plus4;

    always @(posedge clk or posedge rst) begin
        if (rst)
            PC <= 32'h0;
        else if (mispredict)
            PC <= actual_target;
        else if (!stall)
            PC <= pc_next;
    end

    // ============================================================
    // IF/ID PIPELINE REGISTER
    // ============================================================
    reg [31:0] r_IF_ID_pc, r_IF_ID_instr;
    reg        r_IF_ID_predict_taken;
    reg [31:0] r_IF_ID_predict_target;

    assign IF_ID_pc             = r_IF_ID_pc;
    assign IF_ID_instr          = r_IF_ID_instr;
    assign IF_ID_opcode         = IF_ID_instr[6:0];
    assign IF_ID_rs1            = IF_ID_instr[19:15];
    assign IF_ID_rs2            = IF_ID_instr[24:20];
    assign IF_ID_rd             = IF_ID_instr[11:7];
    assign IF_ID_predict_taken  = r_IF_ID_predict_taken;
    assign IF_ID_predict_target = r_IF_ID_predict_target;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            r_IF_ID_pc             <= 32'h0;
            r_IF_ID_instr          <= 32'h00000013;
            r_IF_ID_predict_taken  <= 1'b0;
            r_IF_ID_predict_target <= 32'h0;
        end else if (flush_if_id) begin
            r_IF_ID_pc             <= 32'h0;
            r_IF_ID_instr          <= 32'h00000013;
            r_IF_ID_predict_taken  <= 1'b0;
            r_IF_ID_predict_target <= 32'h0;
        end else if (!stall) begin
            r_IF_ID_pc             <= PC;
            r_IF_ID_instr          <= instr;
            r_IF_ID_predict_taken  <= predict_taken;
            r_IF_ID_predict_target <= predict_target;
        end
    end

    // ============================================================
    // ID STAGE
    // ============================================================
    wire [31:0] imm_out;
    wire [3:0]  ctrl_alu_op;
    wire        ctrl_alu_src, ctrl_mem_to_reg, ctrl_reg_write;
    wire        ctrl_mem_read, ctrl_mem_write, ctrl_branch;
    wire        ctrl_jal, ctrl_jalr;
    wire        ctrl_lui, ctrl_auipc;

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
        .jalr      (ctrl_jalr),
        .lui       (ctrl_lui),
        .auipc     (ctrl_auipc)
    );

    imm_gen imm_gen_inst(
        .instr(IF_ID_instr),
        .imm  (imm_out)
    );

    reg  [31:0] regs [0:31];
    wire [31:0] reg_rdata1, reg_rdata2;

    // Forward WB result to ID to avoid 1-cycle regfile read latency
    assign reg_rdata1 = (IF_ID_rs1 == 0)                            ? 32'h0 :
                        (reg_write_wb && reg_waddr_wb == IF_ID_rs1) ? reg_wdata_wb :
                        regs[IF_ID_rs1];
    assign reg_rdata2 = (IF_ID_rs2 == 0)                            ? 32'h0 :
                        (reg_write_wb && reg_waddr_wb == IF_ID_rs2) ? reg_wdata_wb :
                        regs[IF_ID_rs2];

    integer k;
    initial begin
        for (k = 0; k < 32; k = k + 1) regs[k] = 32'h0;
    end

    reg  [31:0] reg_wdata_wb;
    reg  [4:0]  reg_waddr_wb;
    reg         reg_write_wb;

    always @(posedge clk) begin
        if (reg_write_wb && (reg_waddr_wb != 5'h0))
            regs[reg_waddr_wb] <= reg_wdata_wb;
    end

    wire   load_use_stall = (ID_EX_mem_read &&
                             (ID_EX_rd != 5'h0) &&
                             ((ID_EX_rd == IF_ID_rs1) || (ID_EX_rd == IF_ID_rs2)));

    wire   dcache_stall;   // declared here, driven after dcache inst

    assign stall      = load_use_stall | icache_stall | dcache_stall;
    assign flush_if_id = mispredict;

    // ============================================================
    // ID/EX PIPELINE REGISTER
    // ============================================================
    reg [31:0] r_ID_EX_pc, r_ID_EX_reg_rdata1, r_ID_EX_reg_rdata2, r_ID_EX_imm;
    reg [4:0]  r_ID_EX_rs1, r_ID_EX_rs2, r_ID_EX_rd;
    reg [3:0]  r_ID_EX_alu_op;
    reg [2:0]  r_ID_EX_funct3;
    reg        r_ID_EX_funct7_5;
    reg        r_ID_EX_alu_src, r_ID_EX_mem_to_reg, r_ID_EX_reg_write;
    reg        r_ID_EX_mem_read, r_ID_EX_mem_write, r_ID_EX_branch;
    reg        r_ID_EX_jal, r_ID_EX_jalr;
    reg        r_ID_EX_lui, r_ID_EX_auipc;
    reg        r_ID_EX_predict_taken;
    reg [31:0] r_ID_EX_predict_target;

    assign ID_EX_pc             = r_ID_EX_pc;
    assign ID_EX_reg_rdata1     = r_ID_EX_reg_rdata1;
    assign ID_EX_reg_rdata2     = r_ID_EX_reg_rdata2;
    assign ID_EX_imm            = r_ID_EX_imm;
    assign ID_EX_rs1            = r_ID_EX_rs1;
    assign ID_EX_rs2            = r_ID_EX_rs2;
    assign ID_EX_rd             = r_ID_EX_rd;
    assign ID_EX_alu_op         = r_ID_EX_alu_op;
    assign ID_EX_funct3         = r_ID_EX_funct3;
    assign ID_EX_funct7_5       = r_ID_EX_funct7_5;
    assign ID_EX_alu_src        = r_ID_EX_alu_src;
    assign ID_EX_mem_to_reg     = r_ID_EX_mem_to_reg;
    assign ID_EX_reg_write      = r_ID_EX_reg_write;
    assign ID_EX_mem_read       = r_ID_EX_mem_read;
    assign ID_EX_mem_write      = r_ID_EX_mem_write;
    assign ID_EX_branch         = r_ID_EX_branch;
    assign ID_EX_jal            = r_ID_EX_jal;
    assign ID_EX_jalr           = r_ID_EX_jalr;
    assign ID_EX_lui            = r_ID_EX_lui;
    assign ID_EX_auipc          = r_ID_EX_auipc;
    assign ID_EX_predict_taken  = r_ID_EX_predict_taken;
    assign ID_EX_predict_target = r_ID_EX_predict_target;

    always @(posedge clk or posedge rst) begin
        if (rst || mispredict) begin
            // Flush to NOP
            r_ID_EX_pc             <= 32'h0;
            r_ID_EX_reg_rdata1     <= 32'h0;
            r_ID_EX_reg_rdata2     <= 32'h0;
            r_ID_EX_imm            <= 32'h0;
            r_ID_EX_rs1            <= 5'h0;
            r_ID_EX_rs2            <= 5'h0;
            r_ID_EX_rd             <= 5'h0;
            r_ID_EX_alu_op         <= 4'h0;
            r_ID_EX_funct3         <= 3'h0;
            r_ID_EX_funct7_5       <= 1'b0;
            r_ID_EX_alu_src        <= 1'b0;
            r_ID_EX_mem_to_reg     <= 1'b0;
            r_ID_EX_reg_write      <= 1'b0;
            r_ID_EX_mem_read       <= 1'b0;
            r_ID_EX_mem_write      <= 1'b0;
            r_ID_EX_branch         <= 1'b0;
            r_ID_EX_jal            <= 1'b0;
            r_ID_EX_jalr           <= 1'b0;
            r_ID_EX_lui            <= 1'b0;
            r_ID_EX_auipc          <= 1'b0;
            r_ID_EX_predict_taken  <= 1'b0;
            r_ID_EX_predict_target <= 32'h0;
        end else if (load_use_stall) begin
            // Insert NOP bubble into EX; IF/ID is frozen by !stall above
            r_ID_EX_reg_write  <= 1'b0;
            r_ID_EX_mem_read   <= 1'b0;
            r_ID_EX_mem_write  <= 1'b0;
            r_ID_EX_branch     <= 1'b0;
            r_ID_EX_jal        <= 1'b0;
            r_ID_EX_jalr       <= 1'b0;
            r_ID_EX_lui        <= 1'b0;
            r_ID_EX_auipc      <= 1'b0;
            r_ID_EX_rd         <= 5'h0;
        end else if (!stall) begin
            // Normal capture
            r_ID_EX_pc             <= IF_ID_pc;
            r_ID_EX_reg_rdata1     <= reg_rdata1;
            r_ID_EX_reg_rdata2     <= reg_rdata2;
            r_ID_EX_imm            <= imm_out;
            r_ID_EX_rs1            <= IF_ID_rs1;
            r_ID_EX_rs2            <= IF_ID_rs2;
            r_ID_EX_rd             <= IF_ID_rd;
            r_ID_EX_alu_op         <= ctrl_alu_op;
            r_ID_EX_funct3         <= IF_ID_instr[14:12];
            r_ID_EX_funct7_5       <= IF_ID_instr[30];
            r_ID_EX_alu_src        <= ctrl_alu_src;
            r_ID_EX_mem_to_reg     <= ctrl_mem_to_reg;
            r_ID_EX_reg_write      <= ctrl_reg_write;
            r_ID_EX_mem_read       <= ctrl_mem_read;
            r_ID_EX_mem_write      <= ctrl_mem_write;
            r_ID_EX_branch         <= ctrl_branch;
            r_ID_EX_jal            <= ctrl_jal;
            r_ID_EX_jalr           <= ctrl_jalr;
            r_ID_EX_lui            <= ctrl_lui;
            r_ID_EX_auipc          <= ctrl_auipc;
            r_ID_EX_predict_taken  <= IF_ID_predict_taken;
            r_ID_EX_predict_target <= IF_ID_predict_target;
        end
        // else: dcache_stall (not load-use) — hold ID/EX register value
    end

    // ============================================================
    // EX STAGE
    // ============================================================
    reg [3:0] ex_alu_op_sel;
    always @(*) begin
        case (ID_EX_funct3)
            3'b000: ex_alu_op_sel = (ID_EX_funct7_5 && !ID_EX_alu_src) ? 4'b0001 : 4'b0000; // SUB or ADD
            3'b001: ex_alu_op_sel = 4'b0010; // SLL
            3'b010: ex_alu_op_sel = 4'b0011; // SLT
            3'b011: ex_alu_op_sel = 4'b0100; // SLTU
            3'b100: ex_alu_op_sel = 4'b0101; // XOR
            3'b101: ex_alu_op_sel = ID_EX_funct7_5 ? 4'b0111 : 4'b0110; // SRA or SRL
            3'b110: ex_alu_op_sel = 4'b1000; // OR
            3'b111: ex_alu_op_sel = 4'b1001; // AND
            default: ex_alu_op_sel = 4'b0000;
        endcase
    end

    assign wb_data = MEM_WB_jal        ? MEM_WB_pc_plus4  :
                     MEM_WB_mem_to_reg ? MEM_WB_mem_data   :
                                         MEM_WB_alu_result ;

    // For JAL in EX/MEM stage, forward pc_plus4 not alu_result
    wire [31:0] ex_mem_fwd_data = r_EX_MEM_jal ? r_EX_MEM_pc_plus4 : EX_MEM_alu_result;

    assign forward_a_sel =
        (EX_MEM_reg_write && (EX_MEM_rd != 0) && (EX_MEM_rd == ID_EX_rs1)) ? 2'b10 :
        (MEM_WB_reg_write && (MEM_WB_rd != 0) && (MEM_WB_rd == ID_EX_rs1)) ? 2'b01 : 2'b00;

    assign forward_b_sel =
        (EX_MEM_reg_write && (EX_MEM_rd != 0) && (EX_MEM_rd == ID_EX_rs2)) ? 2'b10 :
        (MEM_WB_reg_write && (MEM_WB_rd != 0) && (MEM_WB_rd == ID_EX_rs2)) ? 2'b01 : 2'b00;

    assign forward_a_out =
        (forward_a_sel == 2'b10) ? ex_mem_fwd_data :
        (forward_a_sel == 2'b01) ? wb_data          : ID_EX_reg_rdata1;

    assign forward_b_out =
        (forward_b_sel == 2'b10) ? ex_mem_fwd_data :
        (forward_b_sel == 2'b01) ? wb_data          : ID_EX_reg_rdata2;

    assign alu_in_a = ID_EX_auipc ? ID_EX_pc  :
                      ID_EX_lui   ? 32'h0      : forward_a_out;
    assign alu_in_b = ID_EX_alu_src ? ID_EX_imm : forward_b_out;

    alu alu_inst(
        .a       (alu_in_a),
        .b       (alu_in_b),
        .alu_op  ((ID_EX_lui || ID_EX_auipc) ? 4'b0000 : ex_alu_op_sel),
        .funct3  (ID_EX_funct3),
        .funct7_5(ID_EX_funct7_5),
        .result  (alu_result),
        .zero    (alu_zero)
    );

    assign branch_target = ID_EX_pc + ID_EX_imm;
    assign jal_target    = ID_EX_pc + ID_EX_imm;
    assign jalr_target   = {alu_result[31:1], 1'b0};
    assign pc_plus4_ex   = ID_EX_pc + 4;

    wire branch_cond =
        (ID_EX_funct3 == 3'b000) ?  alu_zero        :  // BEQ
        (ID_EX_funct3 == 3'b001) ? !alu_zero        :  // BNE
        (ID_EX_funct3 == 3'b100) ?  alu_result[0]   :  // BLT
        (ID_EX_funct3 == 3'b101) ? !alu_result[0]   :  // BGE
        (ID_EX_funct3 == 3'b110) ?  alu_result[0]   :  // BLTU
        (ID_EX_funct3 == 3'b111) ? !alu_result[0]   : 0; // BGEU

    assign branch_taken_ex = (ID_EX_branch && branch_cond) || ID_EX_jal || ID_EX_jalr;
    assign actual_target   = ID_EX_jal                      ? jal_target    :
                             ID_EX_jalr                      ? jalr_target   :
                             (ID_EX_branch && branch_cond)  ? branch_target :
                             pc_plus4_ex;

    assign ex_pc     = ID_EX_pc;
    assign ex_branch = ID_EX_branch || ID_EX_jal || ID_EX_jalr;
    assign ex_taken  = branch_taken_ex;
    assign ex_target = actual_target;
    assign ex_valid  = ex_branch;

    // ============================================================
    // EX/MEM PIPELINE REGISTER
    // ============================================================
    reg [31:0] r_EX_MEM_alu_result, r_EX_MEM_reg_rdata2;
    reg [31:0] r_EX_MEM_pc_plus4;
    reg [4:0]  r_EX_MEM_rd;
    reg        r_EX_MEM_mem_to_reg, r_EX_MEM_reg_write;
    reg        r_EX_MEM_mem_read,   r_EX_MEM_mem_write;
    reg        r_EX_MEM_jal;
    reg        r_EX_MEM_branch;

    assign EX_MEM_alu_result = r_EX_MEM_alu_result;
    assign EX_MEM_reg_write  = r_EX_MEM_reg_write;
    assign EX_MEM_rd         = r_EX_MEM_rd;
    assign EX_MEM_mem_to_reg = r_EX_MEM_mem_to_reg;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            r_EX_MEM_alu_result <= 32'h0;
            r_EX_MEM_reg_rdata2 <= 32'h0;   // FIX: was forward_b_val (undeclared)
            r_EX_MEM_pc_plus4   <= 32'h0;
            r_EX_MEM_rd         <= 5'h0;
            r_EX_MEM_mem_to_reg <= 1'b0;
            r_EX_MEM_reg_write  <= 1'b0;
            r_EX_MEM_mem_read   <= 1'b0;
            r_EX_MEM_mem_write  <= 1'b0;
            r_EX_MEM_jal        <= 1'b0;
            r_EX_MEM_branch     <= 1'b0;
        end else if (!stall) begin
            r_EX_MEM_alu_result <= alu_result;
            r_EX_MEM_reg_rdata2 <= forward_b_out;  // FIX: was forward_b_val (undeclared)
            r_EX_MEM_pc_plus4   <= pc_plus4_ex;
            r_EX_MEM_rd         <= ID_EX_rd;
            r_EX_MEM_mem_to_reg <= ID_EX_mem_to_reg;
            r_EX_MEM_reg_write  <= ID_EX_reg_write;
            r_EX_MEM_mem_read   <= ID_EX_mem_read;
            r_EX_MEM_mem_write  <= ID_EX_mem_write;
            r_EX_MEM_jal        <= ID_EX_jal;
            r_EX_MEM_branch     <= ID_EX_branch || ID_EX_jal || ID_EX_jalr;
        end
    end

    // ============================================================
    // MEM STAGE — DCache
    // ============================================================
    wire [31:0]  mem_read_data;
    wire         dcache_hit;
    wire [31:0]  dcache_rdata;
    wire         dcache_mem_req;
    wire         dcache_mem_write;
    wire [31:0]  dcache_mem_addr;
    wire [127:0] dcache_mem_wdata;
    wire [3:0]   dcache_mem_we;
    wire [127:0] dmem_rdata;
    wire         dmem_dready;

    dcache dcache_inst(
        .clk      (clk),
        .rst      (rst),
        .cpu_addr (r_EX_MEM_alu_result),
        .cpu_wdata(r_EX_MEM_reg_rdata2),
        .cpu_we   (r_EX_MEM_mem_write),
        .cpu_req  (r_EX_MEM_mem_read | r_EX_MEM_mem_write),
        .cpu_rdata(dcache_rdata),
        .cpu_hit  (dcache_hit),
        .mem_req  (dcache_mem_req),
        .mem_write(dcache_mem_write),
        .mem_addr (dcache_mem_addr),
        .mem_wdata(dcache_mem_wdata),
        .mem_we   (dcache_mem_we),
        .mem_rdata(dmem_rdata),
        .mem_ready(dmem_dready)
    );

    assign mem_read_data = dcache_rdata;
    assign dcache_stall  = (r_EX_MEM_mem_read | r_EX_MEM_mem_write) & !dcache_hit;

    // ============================================================
    // MEM/WB PIPELINE REGISTER
    // ============================================================
    reg [31:0] r_MEM_WB_alu_result, r_MEM_WB_mem_data;
    reg [31:0] r_MEM_WB_pc_plus4;
    reg [4:0]  r_MEM_WB_rd;
    reg        r_MEM_WB_mem_to_reg, r_MEM_WB_reg_write;
    reg        r_MEM_WB_jal;
    reg        r_MEM_WB_mem_write;

    assign MEM_WB_alu_result = r_MEM_WB_alu_result;
    assign MEM_WB_mem_data   = r_MEM_WB_mem_data;
    assign MEM_WB_mem_to_reg = r_MEM_WB_mem_to_reg;
    assign MEM_WB_reg_write  = r_MEM_WB_reg_write;
    assign MEM_WB_rd         = r_MEM_WB_rd;
    assign MEM_WB_jal        = r_MEM_WB_jal;
    assign MEM_WB_mem_write  = r_MEM_WB_mem_write;
    assign MEM_WB_pc_plus4   = r_MEM_WB_pc_plus4;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            r_MEM_WB_alu_result <= 32'h0;
            r_MEM_WB_mem_data   <= 32'h0;
            r_MEM_WB_pc_plus4   <= 32'h0;
            r_MEM_WB_rd         <= 5'h0;
            r_MEM_WB_mem_to_reg <= 1'b0;
            r_MEM_WB_reg_write  <= 1'b0;
            r_MEM_WB_jal        <= 1'b0;
            r_MEM_WB_mem_write  <= 1'b0;
        end else if (!stall) begin
            r_MEM_WB_alu_result <= EX_MEM_alu_result;
            r_MEM_WB_mem_data   <= mem_read_data;
            r_MEM_WB_pc_plus4   <= r_EX_MEM_pc_plus4;
            r_MEM_WB_rd         <= r_EX_MEM_rd;
            r_MEM_WB_mem_to_reg <= r_EX_MEM_mem_to_reg;
            r_MEM_WB_reg_write  <= r_EX_MEM_reg_write;
            r_MEM_WB_jal        <= r_EX_MEM_jal;
            r_MEM_WB_mem_write  <= r_EX_MEM_mem_write;
        end
    end

    // ============================================================
    // WB STAGE
    // ============================================================
    always @(*) begin
        if (MEM_WB_jal)
            reg_wdata_wb = MEM_WB_pc_plus4;
        else if (MEM_WB_mem_to_reg)
            reg_wdata_wb = MEM_WB_mem_data;
        else
            reg_wdata_wb = MEM_WB_alu_result;
        reg_waddr_wb = MEM_WB_rd;
        reg_write_wb = MEM_WB_reg_write;
    end

    // ============================================================
    // PERFORMANCE COUNTERS
    // ============================================================
    reg [31:0] cycle_count;
    reg [31:0] instr_count;
    reg [31:0] stall_count;
    reg [31:0] branch_count;
    reg [31:0] mispredict_count;

    always @(posedge clk or posedge rst) begin
        if (rst) cycle_count <= 32'h0;
        else      cycle_count <= cycle_count + 1;
    end

    always @(posedge clk or posedge rst) begin
        if (rst)       stall_count <= 32'h0;
        else if (stall) stall_count <= stall_count + 1;
    end

    wire wb_valid = (MEM_WB_reg_write && (MEM_WB_rd != 5'h0)) || MEM_WB_mem_write;
    always @(posedge clk or posedge rst) begin
        if (rst)          instr_count <= 32'h0;
        else if (wb_valid) instr_count <= instr_count + 1;
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            branch_count     <= 32'h0;
            mispredict_count <= 32'h0;
        end else begin
            if (ID_EX_branch || ID_EX_jal || ID_EX_jalr) begin
                branch_count <= branch_count + 1;
                if (mispredict)
                    mispredict_count <= mispredict_count + 1;
            end
        end
    end

    // ============================================================
    // MAIN MEMORY
    // ============================================================
    main_memory main_mem(
        .clk    (clk),
        .rst    (rst),
        .ireq   (icache_mem_req),
        .iaddr  (icache_mem_addr),
        .idata  (imem_rdata),
        .iready (imem_iready),
        .dreq   (dcache_mem_req),
        .dwrite (dcache_mem_write),
        .daddr  (dcache_mem_addr),
        .dwdata (dcache_mem_wdata),
        .dwe    (dcache_mem_we),
        .drdata (dmem_rdata),
        .dready (dmem_dready)
    );

endmodule
