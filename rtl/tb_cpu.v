`timescale 1ns/1ps
module tb_cpu;
    reg clk, rst;
    pipeline_cpu uut (.clk(clk), .rst(rst));
    initial begin clk = 0; forever #5 clk = ~clk; end
    integer fail = 0;
    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_cpu);
        rst = 1; #20 rst = 0;
        #200;
        $display("\n========== FINAL RESULTS ==========");
        if (uut.regs[1] === 32'd10) $display("x1 = %0d (Expected: 10) PASS", uut.regs[1]);
        else begin $display("x1 = %0d (Expected: 10) FAIL", uut.regs[1]); fail=fail+1; end
        if (uut.regs[2] === 32'd10) $display("x2 = %0d (Expected: 10) PASS", uut.regs[2]);
        else begin $display("x2 = %0d (Expected: 10) FAIL", uut.regs[2]); fail=fail+1; end
        if (uut.regs[3] === 32'd20) $display("x3 = %0d (Expected: 20) PASS - branch flush verified", uut.regs[3]);
        else begin $display("x3 = %0d (Expected: 20) FAIL - branch flush broken!", uut.regs[3]); fail=fail+1; end
        $display("====================================");
        $display("\n========== PERFORMANCE ==========");
        $display("Total cycles  : %0d", uut.cycle_count);
        $display("Instructions  : %0d", uut.instr_count);
        $display("Stall cycles  : %0d", uut.stall_count);
        if (uut.instr_count > 0)
            $display("CPI           : %0.2f", $itor(uut.cycle_count) / $itor(uut.instr_count));
        $display("=================================");
        $display("\n========== TEST STATUS ==========");
        if (fail == 0) $display("ALL TESTS PASSED ✓");
        else $display("%0d TEST(S) FAILED ✗", fail);
        $display("=================================\n");
        $finish;
    end
    initial begin
        $monitor("Time=%0t | PC=%0d | IF_ID=%h | EX_ALU=%0d | stall=%0b | x1=%0d x2=%0d x3=%0d",
                 $time, uut.PC, uut.IF_ID_instr, uut.EX_MEM_alu_result,
                 uut.stall, uut.regs[1], uut.regs[2], uut.regs[3]);
    end
endmodule
