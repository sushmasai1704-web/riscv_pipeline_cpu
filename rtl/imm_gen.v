`timescale 1ns / 1ps

module imm_gen(
    input  [31:0] instr,
    output reg [31:0] imm
);

    wire [6:0] opcode = instr[6:0];

    // Opcode definitions
    localparam OP_IMM = 7'b0010011;
    localparam LOAD   = 7'b0000011;
    localparam STORE  = 7'b0100011;
    localparam BRANCH = 7'b1100011;
    localparam JAL    = 7'b1101111;
    localparam JALR   = 7'b1100111;

    always @(*) begin
        case (opcode)
            // I-type (OP_IMM, LOAD, JALR)
            7'b0010011, 7'b0000011, 7'b1100111:
                imm = {{20{instr[31]}}, instr[31:20]};
            
            // S-type (STORE)
            7'b0100011:
                imm = {{20{instr[31]}}, instr[31:25], instr[11:7]};
            
            // B-type (BRANCH)
            7'b1100011:
                imm = {{20{instr[31]}}, instr[7], instr[30:25], instr[11:8], 1'b0};
            
            // J-type (JAL)
            7'b1101111:
                imm = {{12{instr[31]}}, instr[19:12], instr[20], instr[30:21], 1'b0};
            
            7'b0110111, 7'b0010111:
                imm = {instr[31:12], 12'b0};
            default:
                imm = 32'h0;
        endcase
    end

endmodule
