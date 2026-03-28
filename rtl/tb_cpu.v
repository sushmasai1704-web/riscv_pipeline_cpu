`timescale 1ns/1ps

// ============================================================
// tb_cpu.v — Testbench for pipeline_cpu
// ============================================================
module tb_cpu;

    reg clk, rst;

    pipeline_cpu uut (
        .clk(clk),
        .rst(rst)
    );

    // 10ns clock period
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_cpu);

        rst = 1;
        #20;
        rst = 0;

        // Run for enough cycles
        #400;

        $display("\n========== FINAL RESULTS ==========");
        $display("x1  = %0d (Expected: 36 - JAL return address)", uut.regs[1]);
        $display("x2  = %0d (Expected: 30)",                      uut.regs[2]);
        $display("x3  = %0d (Expected: 30)",                      uut.regs[3]);
        $display("x4  = %0d (Expected: 50)",                      uut.regs[4]);
        $display("x5  = %0d (Expected: 40)",                      uut.regs[5]);
        $display("mem[0] = %0d (Expected: 50)",                   uut.data_mem[0]);
        $display("===================================");

        // CPI report
        $display("\n========== PERFORMANCE ==========");
        $display("Total cycles     : %0d", uut.cycle_count);
        $display("Instructions     : %0d", uut.instr_count);
        $display("Stall cycles     : %0d", uut.stall_count);
        if (uut.instr_count > 0)
            $display("CPI              : %0d.%02d",
                uut.cycle_count / uut.instr_count,
                ((uut.cycle_count * 100) / uut.instr_count) % 100);
        $display("=================================");

        // Pass/Fail check
        $display("\n========== TEST STATUS ==========");
        if (uut.regs[1]==36 && uut.regs[2]==30 && uut.regs[3]==30 &&
            uut.regs[4]==50 && uut.regs[5]==40 && uut.data_mem[0]==50)
            $display("ALL TESTS PASSED ✓");
        else
            $display("SOME TESTS FAILED ✗");
        $display("=================================\n");

        $finish;
    end

    // Pipeline state monitor
    always @(negedge clk) begin
        if (!rst)
            $display("Time=%0t | PC=%0d | IF_ID=%h | EX_ALU=%0d | stall=%b | x1=%0d x2=%0d x3=%0d x4=%0d x5=%0d",
                $time,
                uut.PC,
                uut.IF_ID_instr,
                uut.EX_MEM_alu_result,
                uut.stall,
                uut.regs[1], uut.regs[2], uut.regs[3],
                uut.regs[4], uut.regs[5]);
    end

endmodule
