`timescale 1ns/1ps
module simple_cpu_tb;
    reg clk, rst;
    simple_cpu uut(.clk(clk), .rst(rst));
    always #5 clk = ~clk;
    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, simple_cpu_tb);
        clk = 0; rst = 1;
        #20 rst = 0;
        #300;
        $finish;
    end
endmodule
