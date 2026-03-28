`timescale 1ns/1ps

// ============================================================
// alu.v — RV32I ALU
// Supports: ADD, SUB, SLL, SLT, SLTU, XOR, SRL, SRA, OR, AND
// alu_op encoding matches control.v
// ============================================================
module alu #(
    parameter DATA_WIDTH = 32
)(
    input  [DATA_WIDTH-1:0] a,
    input  [DATA_WIDTH-1:0] b,
    input  [3:0]            alu_op,
    input  [2:0]            funct3,   // needed to pick SRL vs SRA, ADD vs SUB
    input                   funct7_5, // bit 30 of instr → SUB/SRA selector
    output reg [DATA_WIDTH-1:0] result,
    output zero
);

    wire [4:0] shamt = b[4:0]; // shift amount = lower 5 bits

    always @(*) begin
        case (alu_op)
            4'b0000: result = a + b;                              // ADD / ADDI / LW / SW / JAL
            4'b0001: result = a - b;                              // SUB / BEQ compare
            4'b0010: result = a << shamt;                         // SLL / SLLI
            4'b0011: result = ($signed(a) < $signed(b)) ? 32'd1 : 32'd0; // SLT / SLTI
            4'b0100: result = (a < b) ? 32'd1 : 32'd0;           // SLTU / SLTIU
            4'b0101: result = a ^ b;                              // XOR / XORI
            4'b0110: result = a >> shamt;                         // SRL / SRLI
            4'b0111: result = $signed(a) >>> shamt;               // SRA / SRAI
            4'b1000: result = a | b;                              // OR  / ORI
            4'b1001: result = a & b;                              // AND / ANDI
            4'b1010: result = a;                                  // PASS-A (for JAL/JALR)
            default: result = 32'h0;
        endcase
    end

    assign zero = (result == 32'h0);

endmodule
