// ============================================================
// File   : rtl/imm_gen.v
// Description: Immediate generator for RISC-V RV32I
//              Supports I / S / B / U / J immediate formats
// ============================================================

module imm_gen (
    input  wire [31:0] instr,   // Full 32-bit instruction word
    output reg  [31:0] imm_out  // Sign-extended immediate
);

    // ----------------------------------------------------------
    // Opcode for format selection
    // ----------------------------------------------------------
    wire [6:0] opcode = instr[6:0];

    localparam OP_I_ALU  = 7'b0010011; // I-type ALU  → I-imm
    localparam OP_LOAD   = 7'b0000011; // Load        → I-imm
    localparam OP_JALR   = 7'b1100111; // JALR        → I-imm
    localparam OP_STORE  = 7'b0100011; // Store       → S-imm
    localparam OP_BRANCH = 7'b1100011; // Branch      → B-imm
    localparam OP_LUI    = 7'b0110111; // LUI         → U-imm
    localparam OP_AUIPC  = 7'b0010111; // AUIPC       → U-imm
    localparam OP_JAL    = 7'b1101111; // JAL         → J-imm

    // ----------------------------------------------------------
    // Format extraction (combinational)
    // ----------------------------------------------------------

    // I-immediate: instr[31:20]
    wire [31:0] i_imm = {{20{instr[31]}}, instr[31:20]};

    // S-immediate: instr[31:25] | instr[11:7]
    wire [31:0] s_imm = {{20{instr[31]}}, instr[31:25], instr[11:7]};

    // B-immediate: instr[31] | instr[7] | instr[30:25] | instr[11:8] | 1'b0
    wire [31:0] b_imm = {{19{instr[31]}}, instr[31], instr[7],
                          instr[30:25], instr[11:8], 1'b0};

    // U-immediate: instr[31:12] << 12  (lower 12 bits = 0)
    wire [31:0] u_imm = {instr[31:12], 12'b0};

    // J-immediate: instr[31] | instr[19:12] | instr[20] | instr[30:21] | 1'b0
    wire [31:0] j_imm = {{11{instr[31]}}, instr[31], instr[19:12],
                          instr[20], instr[30:21], 1'b0};

    // ----------------------------------------------------------
    // Mux based on opcode
    // ----------------------------------------------------------
    always @(*) begin
        case (opcode)
            OP_I_ALU,
            OP_LOAD,
            OP_JALR  : imm_out = i_imm;
            OP_STORE  : imm_out = s_imm;
            OP_BRANCH : imm_out = b_imm;
            OP_LUI,
            OP_AUIPC  : imm_out = u_imm;
            OP_JAL    : imm_out = j_imm;
            default   : imm_out = 32'b0;
        endcase
    end

endmodule
