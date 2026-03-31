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
    localparam OP_R      = 7'b0110011;
    localparam OP_I_ALU  = 7'b0010011;
    localparam OP_LOAD   = 7'b0000011;
    localparam OP_STORE  = 7'b0100011;
    localparam OP_BRANCH = 7'b1100011;
    localparam OP_JAL    = 7'b1101111;
    localparam OP_JALR   = 7'b1100111;
    localparam OP_LUI    = 7'b0110111;
    localparam OP_AUIPC  = 7'b0010111;

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
    localparam ALU_PASS = 4'b1010;

    always @(*) begin
        alu_op     = ALU_ADD;
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
            OP_R: begin
                reg_write = 1'b1;
            end
            OP_I_ALU: begin
                alu_src   = 1'b1;
                reg_write = 1'b1;
            end
            OP_LOAD: begin
                alu_src    = 1'b1;
                mem_to_reg = 1'b1;
                reg_write  = 1'b1;
                mem_read   = 1'b1;
            end
            OP_STORE: begin
                alu_src   = 1'b1;
                mem_write = 1'b1;
            end
            OP_BRANCH: begin
                branch = 1'b1;
            end
            OP_JAL: begin
                jal       = 1'b1;
                reg_write = 1'b1;
            end
            OP_JALR: begin
                jalr      = 1'b1;
                alu_src   = 1'b1;
                reg_write = 1'b1;
            end
            OP_LUI: begin
                alu_op    = ALU_PASS;
                alu_src   = 1'b1;
                reg_write = 1'b1;
                lui       = 1'b1;
            end
            OP_AUIPC: begin
                alu_op    = ALU_ADD;
                alu_src   = 1'b1;
                reg_write = 1'b1;
                auipc     = 1'b1;
            end
            default: ;
        endcase
    end
endmodule
