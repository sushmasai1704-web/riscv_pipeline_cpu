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

    // Opcode definitions
    localparam OP_IMM = 7'b0010011;  // I-type ALU
    localparam OP     = 7'b0110011;  // R-type ALU
    localparam LOAD   = 7'b0000011;  // Load
    localparam STORE  = 7'b0100011;  // Store
    localparam BRANCH = 7'b1100011;  // Branch
    localparam JAL    = 7'b1101111;  // JAL
    localparam JALR   = 7'b1100111;  // JALR

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
            7'b0110111: begin // LUI
                alu_src=1'b1; reg_write=1'b1; lui=1'b1;
            end
            7'b0010111: begin // AUIPC
                alu_src=1'b1; reg_write=1'b1; auipc=1'b1;
            end
            default: ;
        endcase
    end

endmodule
