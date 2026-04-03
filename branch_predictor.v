module branch_predictor(
  input clk,
  input rst_n,
  input [31:0] pc,
  input predict_req,
  output predict_taken,
  output [31:0] predict_target,
  output predict_valid,
  input [31:0] ex_pc,
  input ex_branch,
  input ex_taken,
  input [31:0] ex_target,
  input ex_valid
);

assign predict_taken = 0;
assign predict_target = 0;
assign predict_valid = 0;

endmodule
