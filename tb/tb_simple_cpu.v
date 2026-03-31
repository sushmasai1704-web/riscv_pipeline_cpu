`timescale 1ns/1ps
module simple_cpu_tb;
    reg clk, rst;
    simple_cpu cpu_inst(.clk(clk), .rst(rst));

    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, simple_cpu_tb);
        rst = 1;
        repeat(3) @(posedge clk);
        rst = 0;
        repeat(20) @(posedge clk);
        // Check AFTER pipeline drains
        $display("=== FINAL RESULTS ===");
        $display("x5 = %0d (expect 4)",  cpu_inst.regs[5]);
        $display("x6 = %0d (expect 10)", cpu_inst.regs[6]);
        $display("x8 = %0d (expect 20)", cpu_inst.regs[8]);
        $finish;
    end
endmodule
