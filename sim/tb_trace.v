`timescale 1ns/1ps
module tb_trace;
reg clk, rst;
pipeline_cpu uut(.clk(clk),.rst(rst));
initial clk=0;
always #5 clk=~clk;
always @(posedge clk) begin
    if (!rst && (uut.r_EX_MEM_mem_write || uut.r_EX_MEM_mem_read))
        $display("MEM t=%0t addr=%h wr=%b hit=%b stall=%b pend=%b state=%0d mreq=%b mready=%b",
            $time, uut.r_EX_MEM_alu_result,
            uut.r_EX_MEM_mem_write,
            uut.dcache_inst.cpu_hit,
            uut.dcache_stall,
            uut.dcache_inst.pending,
            uut.dcache_inst.state,
            uut.dcache_inst.mem_req,
            uut.dmem_dready);
end
initial begin
    rst=1; repeat(2) @(posedge clk); #1; rst=0;
    repeat(500) @(posedge clk);
    $display("dcache data[10][0]=%h valid=%b state=%0d pending=%b",
        uut.dcache_inst.data[10][0],
        uut.dcache_inst.valid[10],
        uut.dcache_inst.state,
        uut.dcache_inst.pending);
    $finish;
end
endmodule
