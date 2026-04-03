module icache(
  input clk,
  input rst,
  input [31:0] cpu_addr,
  output reg [31:0] cpu_rdata,
  output cpu_hit,
  input cpu_req,
  output mem_req,
  output [31:0] mem_addr,
  input [127:0] mem_rdata,
  input mem_ready
);

assign cpu_hit = 1'b1;
assign mem_req = 0;
assign mem_addr = 0;

always @(*) begin
  case (cpu_addr)
    32'h0: cpu_rdata = 32'h002081b3; // ADD x3,x1,x2
    32'h4: cpu_rdata = 32'h402081b3; // SUB
    32'h8: cpu_rdata = 32'h0020a233; // SLT
    32'hC: cpu_rdata = 32'h00000013; // NOP
    default: cpu_rdata = 32'h00000013;
  endcase
end

endmodule
