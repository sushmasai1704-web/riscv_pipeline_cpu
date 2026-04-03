`timescale 1ns / 1ps
module tb_cpu;
    reg clk, rst;
    pipeline_cpu uut (.clk(clk), .rst(rst));
    initial clk = 0;
    always #5 clk = ~clk;
    integer pass_count = 0;
    integer fail_count = 0;

    always @(posedge clk) begin
        if (!rst && uut.r_EX_MEM_mem_write)
            $display("SW_IN_MEM t=%0t addr=%08h wdata=%08h hit=%b stall=%b pend=%b state=%0d mreq=%b mready=%b",
                $time, uut.r_EX_MEM_alu_result, uut.r_EX_MEM_reg_rdata2,
                uut.dcache_inst.cpu_hit, uut.dcache_stall,
                uut.dcache_inst.pending, uut.dcache_inst.state,
                uut.dcache_mem_req, uut.dmem_dready);
    end

    task check;
        input [255:0] name;
        input [31:0] got, exp;
        begin
            if (got === exp) begin
                $display("  PASS  %-22s got=0x%08h", name, got);
                pass_count = pass_count + 1;
            end else begin
                $display("  FAIL  %-22s got=0x%08h  exp=0x%08h", name, got, exp);
                fail_count = fail_count + 1;
            end
        end
    endtask

    function [31:0] dmem;
        input [31:0] addr;
        dmem = uut.dcache_inst.data[addr[7:4]][addr[3:2]];
    endfunction

    initial begin
        rst = 1;
        @(posedge clk); #1;
        @(posedge clk); #1;
        rst = 0;
        repeat(15000) @(posedge clk);
        $display("");
        $display("=== Functional checks ===");
        check("ADD(10+20=30)",      dmem(32'h0A0), 32'h0000001E);
        check("SUB(30-10=20)",      dmem(32'h0A4), 32'h00000014);
        check("SLT(10<20=1)",       dmem(32'h0A8), 32'h00000001);
        check("SLT(20<10=0)",       dmem(32'h0AC), 32'h00000000);
        check("SLTI(10<15=1)",      dmem(32'h0B0), 32'h00000001);
        check("SLTI(10<5=0)",       dmem(32'h0B4), 32'h00000000);
        check("SRA(-80>>>3=-10)",   dmem(32'h0B8), 32'hFFFFFFF6);
        check("LUI(0xABCDE000)",    dmem(32'h0BC), 32'hABCDE000);
        check("AUIPC(84+4096)",     dmem(32'h0C0), 32'h00001054);
        check("BEQ taken(0xBB)",    dmem(32'h0C4), 32'h000000BB);
        check("BNE taken(0xCC)",    dmem(32'h0C8), 32'h000000CC);
        check("JAL link(=128)",     dmem(32'h0CC), 32'h00000080);
        check("JALR link(=144)",    dmem(32'h0D0), 32'h00000090);
        $display("");
        $display("=== Register checks ===");
        check("x1=10",          uut.regs[1],  32'h0000000A);
        check("x2=20",          uut.regs[2],  32'h00000014);
        check("x3=30",          uut.regs[3],  32'h0000001E);
        check("x6=1 SLT true",  uut.regs[6],  32'h00000001);
        check("x7=0 SLT false", uut.regs[7],  32'h00000000);
        check("x8=1 SLTI true", uut.regs[8],  32'h00000001);
        check("x9=0 SLTI false",uut.regs[9],  32'h00000000);
        check("x29=-10 SRA",    uut.regs[29], 32'hFFFFFFF6);
        check("x30=LUI",        uut.regs[30], 32'hABCDE000);
        $display("");
        $display("  dcache data[10][0]=%h valid[10]=%b", uut.dcache_inst.data[10][0], uut.dcache_inst.valid[10]);
        $display("  last SW addr=%h", uut.r_EX_MEM_alu_result);
        $display("");
        $display("=== Summary: %0d PASS  %0d FAIL ===", pass_count, fail_count);
        if (fail_count > 0) $display("*** %0d FAILED ***", fail_count);
        else $display("*** ALL PASSED ***");
        $finish;
    end
endmodule
