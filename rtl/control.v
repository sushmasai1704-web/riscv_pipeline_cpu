`timescale 1ns/1ps

// ============================================================
// control.v — RV32I Control Unit
// Decodes opcode → control signals for pipeline_cpu.v
// ============================================================
module control(
    input  [6:0] opcode,
    output reg [3:0] alu_op,
    output reg alu_src,
    output reg mem_to_reg,
    output reg reg_write,
    output reg mem_read,
    output reg mem_write,
    output reg branch,
    output reg jal,
    output reg jalr
);

    // RISC-V Opcodes
    localparam OP_R      = 7'b0110011; // R-type  (add, sub, and, or, xor, sll, srl, sra, slt)
    localparam OP_I_ALU  = 7'b0010011; // I-type  (addi, andi, ori, xori, slli, srli, srai, slti)
    localparam OP_LOAD   = 7'b0000011; // Load    (lw)
    localparam OP_STORE  = 7'b0100011; // Store   (sw)
    localparam OP_BRANCH = 7'b1100011; // Branch  (beq, bne, blt)
    localparam OP_JAL    = 7'b1101111; // JAL
    localparam OP_JALR   = 7'b1100111; // JALR

    // ALU op encoding (must match alu.v)
    localparam ALU_ADD  = 4'b0000;
    localparam ALU_SUB  = 4'b0001;
    localparam ALU_SLL  = 4'b0010;
    localparam ALU_SLT  = 4'b0011;
    localparam ALU_SLTU = 4'b0100;
    localparam ALU_XOR  = 4'b0101;
    localparam ALU_SRL  = 4'b0110;
    localparam ALU_SRA  = 4'b0111;
    localparam ALU_OR   = 4'b1000;
    localparam ALU_AND  = 4'b1001;
    localparam ALU_PASS = 4'b1010; // pass a (for JAL/JALR PC+4)

    always @(*) begin
        // Safe defaults — NOP
        alu_op    = ALU_ADD;
        alu_src   = 0;
        mem_to_reg= 0;
        reg_write = 0;
        mem_read  = 0;
        mem_write = 0;
        branch    = 0;
        jal       = 0;
        jalr      = 0;

        case (opcode)
            OP_R: begin
                // funct3/funct7 decoded in EX stage via alu_op from ID
                // control just enables reg write, ALU uses regs
                alu_op    = ALU_ADD;  // placeholder; EX overrides via funct
                alu_src   = 0;
                reg_write = 1;
            end

            OP_I_ALU: begin
                alu_op    = ALU_ADD;  // placeholder; EX overrides via funct
                alu_src   = 1;        // use immediate
                reg_write = 1;
            end

            OP_LOAD: begin
                alu_op    = ALU_ADD;
                alu_src   = 1;
                mem_to_reg= 1;
                reg_write = 1;
                mem_read  = 1;
            end

            OP_STORE: begin
                alu_op    = ALU_ADD;
                alu_src   = 1;
                mem_write = 1;
            end

            OP_BRANCH: begin
                alu_op    = ALU_SUB;  // SUB → zero flag for BEQ
                alu_src   = 0;
                branch    = 1;
            end

            OP_JAL: begin
                alu_op    = ALU_ADD;
                jal       = 1;
                reg_write = 1;        // write PC+4 to rd
            end

            OP_JALR: begin
                alu_op    = ALU_ADD;
                alu_src   = 1;
                jalr      = 1;
                reg_write = 1;
            end

            default: begin
                // NOP / unknown — all zeros
            end
        endcase
    end

endmodule
