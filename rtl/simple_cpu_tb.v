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
        #200;
        $display("");
        $display("========== FINAL REGISTER VALUES ==========");
        $display("x1  = %0d  (expected: 10)",  uut.regs[1]);
        $display("x2  = %0d  (expected: 20)",  uut.regs[2]);
        $display("x3  = %0d  (expected: 5)",   uut.regs[3]);
        $display("x4  = %0d  (expected: 30)",  uut.regs[4]);
        $display("x5  = %0d  (expected: 35)",  uut.regs[5]);
        $display("x6  = %0d  (expected: 135)", uut.regs[6]);
        $display("x7  = %0d  (expected: 15)",  uut.regs[7]);
        $display("x8  = %0d  (expected: 22)",  uut.regs[8]);
        $display("x9  = %0d  (expected: 157)", uut.regs[9]);
        $display("x10 = %0d  (expected: 42)",  uut.regs[10]);
        $display("===========================================");
        if(uut.regs[1]==10  && uut.regs[2]==20  && uut.regs[3]==5   &&
           uut.regs[4]==30  && uut.regs[5]==35  && uut.regs[6]==135 &&
           uut.regs[7]==15  && uut.regs[8]==22  && uut.regs[9]==157 &&
           uut.regs[10]==42)
            $display("ALL TESTS PASSED ✓");
        else
            $display("SOME TESTS FAILED ✗");
        $finish;
    end
endmodule
