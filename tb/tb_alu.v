`timescale 1ns/1ps

module tb_alu;

    reg [31:0] a, b;
    reg [3:0] alu_op;
    wire [31:0] result;
    wire zero;

    alu uut (
        .a(a),
        .b(b),
        .alu_op(alu_op),
        .result(result),
        .zero(zero)
    );

    initial begin
        $display("ALU TEST START");

        a=5; b=3; alu_op=4'b0000; #10;
        $display("ADD = %d", result);

        a=10; b=4; alu_op=4'b0001; #10;
        $display("SUB = %d", result);

        a=5; b=5; alu_op=4'b0001; #10;
        $display("ZERO = %b", zero);

        $finish;
    end

endmodule