`timescale 1ns/1ps
module branch_predictor #(
    parameter INDEX_BITS = 8
)(
    input wire clk,
    input wire rst_n,
    input wire [31:0] pc,
    input wire predict_req,
    output wire predict_taken,
    output wire [31:0] predict_target,
    output wire predict_valid,
    input wire [31:0] ex_pc,
    input wire ex_branch,
    input wire ex_taken,
    input wire [31:0] ex_target,
    input wire ex_valid
);

reg [1:0]  bht        [0:(1<<INDEX_BITS)-1];
reg [31:0] btb_pc     [0:(1<<INDEX_BITS)-1];
reg [31:0] btb_target [0:(1<<INDEX_BITS)-1];
reg        btb_valid  [0:(1<<INDEX_BITS)-1];

wire [INDEX_BITS-1:0] index    = pc[INDEX_BITS+1:2];
wire [INDEX_BITS-1:0] ex_index = ex_pc[INDEX_BITS+1:2];

assign predict_valid  = btb_valid[index] && (btb_pc[index] == pc);
assign predict_taken  = predict_valid && (bht[index][1] == 1'b1);
assign predict_target = btb_target[index];

integer i;  // <-- moved here, module scope, legal in Verilog-2001

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        for (i = 0; i < (1<<INDEX_BITS); i = i + 1) begin
            bht[i]       <= 2'b01;
            btb_valid[i] <= 1'b0;
        end
    end else if (ex_valid && ex_branch) begin
        if (ex_taken) begin
            if (bht[ex_index] != 2'b11)
                bht[ex_index] <= bht[ex_index] + 1;
        end else begin
            if (bht[ex_index] != 2'b00)
                bht[ex_index] <= bht[ex_index] - 1;
        end
        btb_pc[ex_index]     <= ex_pc;
        btb_target[ex_index] <= ex_target;
        btb_valid[ex_index]  <= 1'b1;
    end
end

endmodule
