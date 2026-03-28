`timescale 1ns/1ps

module tb_control_simple;

    reg [6:0] opcode;
    reg [2:0] funct3;

    wire [3:0] alu_op;
    wire reg_write;
    wire alu_src;

    control_simple uut (
        .opcode(opcode),
        .funct3(funct3),
        .alu_op(alu_op),
        .reg_write(reg_write),
        .alu_src(alu_src)
    );

    initial begin
        // Test ADD (R-type)
        opcode = 7'b0110011;
        funct3 = 3'b000;
        #10;
        $display("ADD -> alu_op=%b reg_write=%b", alu_op, reg_write);

        // Test AND
        funct3 = 3'b111;
        #10;
        $display("AND -> alu_op=%b", alu_op);

        // Test ADDI
        opcode = 7'b0010011;
        #10;
        $display("ADDI -> alu_src=%b reg_write=%b", alu_src, reg_write);

        $finish;
    end

endmodule
