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
        wait(uut.instr_count == 8); repeat(4) @(posedge clk);
        $display("\n========== FINAL RESULTS ==========");
        if (uut.regs[1] === 32'd36) $display("x1  = %0d (Expected: 36) PASS", uut.regs[1]);
        else begin $display("x1  = %0d (Expected: 36) FAIL", uut.regs[1]); fail=fail+1; end
        if (uut.regs[2] === 32'd30) $display("x2  = %0d (Expected: 30) PASS", uut.regs[2]);
        else begin $display("x2  = %0d (Expected: 30) FAIL", uut.regs[2]); fail=fail+1; end
        if (uut.regs[3] === 32'd30) $display("x3  = %0d (Expected: 30) PASS", uut.regs[3]);
        else begin $display("x3  = %0d (Expected: 30) FAIL", uut.regs[3]); fail=fail+1; end
        if (uut.regs[4] === 32'd50) $display("x4  = %0d (Expected: 50) PASS", uut.regs[4]);
        else begin $display("x4  = %0d (Expected: 50) FAIL", uut.regs[4]); fail=fail+1; end
        if (uut.regs[5] === 32'd40) $display("x5  = %0d (Expected: 40) PASS", uut.regs[5]);
        else begin $display("x5  = %0d (Expected: 40) FAIL", uut.regs[5]); fail=fail+1; end
        if (uut.data_mem[0] === 32'd50) $display("mem[0] = %0d (Expected: 50) PASS", uut.data_mem[0]);
        else begin $display("mem[0] = %0d (Expected: 50) FAIL", uut.data_mem[0]); fail=fail+1; end
        $display("====================================");
        $display("\n========== PERFORMANCE ==========");
        $display("Total cycles     : %0d", uut.cycle_count);
        $display("Instructions     : %0d", uut.instr_count);
        $display("Stall cycles     : %0d", uut.stall_count);
        $display("Branch count     : %0d", uut.branch_count);
        $display("Mispredictions   : %0d", uut.mispredict_count);
        if (uut.instr_count > 0)
            $display("CPI              : %0.2f", $itor(uut.cycle_count) / $itor(uut.instr_count));
        if (uut.branch_count > 0)
            $display("Mispredict rate  : %0.1f%%", 100.0 * $itor(uut.mispredict_count) / $itor(uut.branch_count));
        $display("=================================");
        $display("\n========== TEST STATUS ==========");
        if (fail == 0) $display("ALL TESTS PASSED ✓");
        else $display("%0d TEST(S) FAILED ✗", fail);
        $display("=================================\n");
        $finish;
    end
    initial begin
        $monitor("Time=%0t | PC=%0d | IF_ID=%h | stall=%0b | mispredict=%0b | x1=%0d x2=%0d x3=%0d x4=%0d x5=%0d",
                 $time, uut.PC, uut.IF_ID_instr, uut.stall, uut.mispredict,
                 uut.regs[1], uut.regs[2], uut.regs[3], uut.regs[4], uut.regs[5]);
    end
endmodule
