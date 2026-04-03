// ============================================================
// File   : rtl/alu.v
// Description: 32-bit ALU for RISC-V RV32I
// Operations : ADD, SUB, AND, OR, XOR, SLL, SRL, SRA, SLT, SLTU
// ============================================================

module alu (
    input  wire [31:0] operand_a,   // RS1 or PC
    input  wire [31:0] operand_b,   // RS2 or Immediate
    input  wire [ 3:0] alu_ctrl,    // ALU operation select
    output reg  [31:0] alu_result,  // Result
    output wire        zero,        // Zero flag (for branch)
    output wire        negative,    // Negative flag
    output wire        overflow     // Overflow flag
);

    // ----------------------------------------------------------
    // ALU Control Encoding
    // ----------------------------------------------------------
    localparam ALU_ADD  = 4'b0000;
    localparam ALU_SUB  = 4'b0001;
    localparam ALU_AND  = 4'b0010;
    localparam ALU_OR   = 4'b0011;
    localparam ALU_XOR  = 4'b0100;
    localparam ALU_SLL  = 4'b0101;
    localparam ALU_SRL  = 4'b0110;
    localparam ALU_SRA  = 4'b0111;
    localparam ALU_SLT  = 4'b1000;
    localparam ALU_SLTU = 4'b1001;
    localparam ALU_LUI  = 4'b1010;  // pass B (for LUI)
    localparam ALU_AUIPC= 4'b1011;  // ADD used for AUIPC

    // ----------------------------------------------------------
    // Internal wires
    // ----------------------------------------------------------
    wire [31:0] add_result  = operand_a + operand_b;
    wire [31:0] sub_result  = operand_a - operand_b;
    wire [4:0]  shamt       = operand_b[4:0];

    // Signed comparison
    wire signed_lt  = ($signed(operand_a) < $signed(operand_b));
    // Unsigned comparison
    wire unsigned_lt = (operand_a < operand_b);

    // Overflow detection for ADD
    wire add_overflow = (~operand_a[31] & ~operand_b[31] &  add_result[31]) |
                        ( operand_a[31] &  operand_b[31] & ~add_result[31]);
    // Overflow detection for SUB
    wire sub_overflow = (~operand_a[31] &  operand_b[31] &  sub_result[31]) |
                        ( operand_a[31] & ~operand_b[31] & ~sub_result[31]);

    // ----------------------------------------------------------
    // ALU Operation
    // ----------------------------------------------------------
    always @(*) begin
        case (alu_ctrl)
            ALU_ADD  : alu_result = add_result;
            ALU_SUB  : alu_result = sub_result;
            ALU_AND  : alu_result = operand_a & operand_b;
            ALU_OR   : alu_result = operand_a | operand_b;
            ALU_XOR  : alu_result = operand_a ^ operand_b;
            ALU_SLL  : alu_result = operand_a << shamt;
            ALU_SRL  : alu_result = operand_a >> shamt;
            ALU_SRA  : alu_result = $signed(operand_a) >>> shamt;
            ALU_SLT  : alu_result = {31'b0, signed_lt};
            ALU_SLTU : alu_result = {31'b0, unsigned_lt};
            ALU_LUI  : alu_result = operand_b;
            ALU_AUIPC: alu_result = add_result;
            default  : alu_result = 32'b0;
        endcase
    end

    // ----------------------------------------------------------
    // Status flags
    // ----------------------------------------------------------
    assign zero     = (alu_result == 32'b0);
    assign negative = alu_result[31];
    assign overflow = (alu_ctrl == ALU_ADD) ? add_overflow :
                      (alu_ctrl == ALU_SUB) ? sub_overflow : 1'b0;

endmodule
