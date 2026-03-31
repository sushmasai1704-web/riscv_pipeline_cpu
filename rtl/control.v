`timescale 1ns / 1ps

module control(
    input  [6:0] opcode,
    output reg [3:0] alu_op,
    output reg       alu_src,
    output reg       mem_to_reg,
    output reg       reg_write,
    output reg       mem_read,
    output reg       mem_write,
    output reg       branch,
    output reg       jal,
    output reg       jalr,
    output reg       lui,
    output reg       auipc
);

<<<<<<< HEAD
    // RISC-V Opcodes
    localparam OP_R      = 7'b0110011; // R-type  (add, sub, and, or, xor, sll, srl, sra, slt)
    localparam OP_I_ALU  = 7'b0010011; // I-type  (addi, andi, ori, xori, slli, srli, srai, slti)
    localparam OP_LOAD   = 7'b0000011; // Load    (lw)
    localparam OP_STORE  = 7'b0100011; // Store   (sw)
    localparam OP_BRANCH = 7'b1100011; // Branch  (beq, bne, blt)
    localparam OP_JAL    = 7'b1101111; // JAL
    localparam OP_JALR   = 7'b1100111; // JALR
    localparam OP_LUI    = 7'b0110111; // LUI
    localparam OP_AUIPC  = 7'b0010111; // AUIPC

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
=======
    // Opcode definitions
    localparam OP_IMM = 7'b0010011;  // I-type ALU
    localparam OP     = 7'b0110011;  // R-type ALU
    localparam LOAD   = 7'b0000011;  // Load
    localparam STORE  = 7'b0100011;  // Store
    localparam BRANCH = 7'b1100011;  // Branch
    localparam JAL    = 7'b1101111;  // JAL
    localparam JALR   = 7'b1100111;  // JALR
>>>>>>> 2a2713820fd89ac6a4c8748888c94268dbf07c77

    always @(*) begin
        // Defaults
        alu_op     = 4'b0000;
        alu_src    = 1'b0;
        mem_to_reg = 1'b0;
        reg_write  = 1'b0;
        mem_read   = 1'b0;
        mem_write  = 1'b0;
        branch     = 1'b0;
        jal        = 1'b0;
        jalr       = 1'b0;
        lui        = 1'b0;
        auipc      = 1'b0;

        case (opcode)
            OP_IMM: begin
                alu_src   = 1'b1;
                reg_write = 1'b1;
            end
            OP: begin
                reg_write = 1'b1;
            end
            LOAD: begin
                alu_src    = 1'b1;
                mem_to_reg = 1'b1;
                reg_write  = 1'b1;
                mem_read   = 1'b1;
            end
            STORE: begin
                alu_src   = 1'b1;
                mem_write = 1'b1;
            end
            BRANCH: begin
                branch = 1'b1;
            end
            JAL: begin
                jal       = 1'b1;
                reg_write = 1'b1;
            end
            JALR: begin
                jalr      = 1'b1;
                alu_src   = 1'b1;
                reg_write = 1'b1;
            end
<<<<<<< HEAD
 
            OP_LUI: begin
                alu_op    = ALU_PASS;
                alu_src   = 1;
                reg_write = 1;
            end
            OP_AUIPC: begin
                alu_op    = ALU_ADD;
                alu_src   = 1;
                reg_write = 1;
            end
            default: begin
=======
            7'b0110111: begin // LUI
                alu_src=1'b1; reg_write=1'b1; lui=1'b1;
            end
            7'b0010111: begin // AUIPC
                alu_src=1'b1; reg_write=1'b1; auipc=1'b1;
>>>>>>> 2a2713820fd89ac6a4c8748888c94268dbf07c77
            end
            default: ;
        endcase
    end
endmodule
