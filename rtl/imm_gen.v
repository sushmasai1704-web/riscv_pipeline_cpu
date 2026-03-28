`timescale 1ns/1ps

module imm_gen(
    input  [31:0] instr,
    output reg [31:0] imm
);

    wire [6:0] opcode = instr[6:0];

    always @(*) begin
        case (opcode)
            // I-type (ADDI, LW, JALR)
            7'b0010011, // ADDI
            7'b0000011, // LW
            7'b1100111: // JALR
                imm = {{20{instr[31]}}, instr[31:20]};
            
            // S-type (SW)
            7'b0100011:
                imm = {{20{instr[31]}}, instr[31:25], instr[11:7]};
            
            // B-type (BEQ, BNE, etc.) - offset in bytes, multiplied by 2
            7'b1100011:
                imm = {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};
            
            // J-type (JAL) - IMPORTANT: scattered immediate bits
            7'b1101111:
                imm = {{11{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0};
            
            // U-type (LUI, AUIPC)
            7'b0110111, // LUI
            7'b0010111: // AUIPC
                imm = {instr[31:12], 12'b0};
            
            default:
                imm = 32'b0;
        endcase
    end

endmodule
