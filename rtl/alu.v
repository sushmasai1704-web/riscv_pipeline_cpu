`timescale 1ns / 1ps

module alu(
    input  [31:0] a,
    input  [31:0] b,
    input  [3:0]  alu_op,
    input  [2:0]  funct3,
    input         funct7_5,
    output reg [31:0] result,
    output        zero
);

    assign zero = (result == 32'h0);

    always @(*) begin
        case (alu_op)
            4'b0000: result = a + b;           // ADD, ADDI
            4'b0001: result = a - b;           // SUB
            4'b0010: result = a << b[4:0];     // SLL, SLLI
            4'b0011: result = ($signed(a) < $signed(b)) ? 32'h1 : 32'h0; // SLT, SLTI
            4'b0100: result = (a < b) ? 32'h1 : 32'h0;                   // SLTU, SLTIU
            4'b0101: result = a ^ b;           // XOR, XORI
            4'b0110: result = a >> b[4:0];     // SRL, SRLI
            4'b0111: result = $signed(a) >>> b[4:0]; // SRA, SRAI
            4'b1000: result = a | b;           // OR, ORI
            4'b1001: result = a & b;           // AND, ANDI
            default: result = 32'h0;
        endcase
    end

endmodule
