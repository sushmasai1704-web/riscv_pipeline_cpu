`timescale 1ns/1ps

module tb_id_simple;

    reg [31:0] instr;

    wire [4:0] rs1, rs2, rd;
    wire [6:0] opcode;
    wire [2:0] funct3;

    id_simple uut (
        .instr(instr),
        .rs1(rs1),
        .rs2(rs2),
        .rd(rd),
        .opcode(opcode),
        .funct3(funct3)
    );

    initial begin
        // Example: ADD x3, x1, x2
        // opcode=0110011, rs1=1, rs2=2, rd=3
        instr = 32'b0000000_00010_00001_000_00011_0110011;

        #10;

        $display("rs1 = %d (expected 1)", rs1);
        $display("rs2 = %d (expected 2)", rs2);
        $display("rd  = %d (expected 3)", rd);
        $display("opcode = %b", opcode);

        $finish;
    end

endmodule
