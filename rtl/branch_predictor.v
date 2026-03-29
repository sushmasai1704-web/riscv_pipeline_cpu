`timescale 1ns / 1ps

module branch_predictor #(
    parameter INDEX_BITS = 8
)(
    input wire clk,
    input wire rst_n,
    
    input wire [31:0] pc,
    input wire predict_req,
    
    output reg predict_taken,
    output reg [31:0] predict_target,
    output reg predict_valid,
    
    input wire [31:0] ex_pc,
    input wire ex_branch,
    input wire ex_taken,
    input wire [31:0] ex_target,
    input wire ex_valid
);

    // 256-entry BHT (2-bit saturating counters)
    // 00 = Strongly Not Taken, 01 = Weakly Not Taken
    // 10 = Weakly Taken, 11 = Strongly Taken
    reg [1:0] bht [0:(1<<INDEX_BITS)-1];
    
    // Branch Target Buffer
    reg [31:0] btb_target [0:(1<<INDEX_BITS)-1];
    reg        btb_valid  [0:(1<<INDEX_BITS)-1];
    
    wire [INDEX_BITS-1:0] index = pc[INDEX_BITS+1:2];
    wire [INDEX_BITS-1:0] ex_index = ex_pc[INDEX_BITS+1:2];
    
    integer i;
    
    // Prediction logic (combinational)
    always @(*) begin
        if (btb_valid[index]) begin
            predict_valid = 1'b1;
            predict_taken = bht[index][1];  // MSB of counter
            predict_target = btb_target[index];
        end else begin
            predict_valid = 1'b0;
            predict_taken = 1'b0;
            predict_target = 32'h0;
        end
    end
    
    // Update logic (sequential)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < (1<<INDEX_BITS); i = i + 1) begin
                bht[i] <= 2'b01;  // Weakly Not Taken
                btb_valid[i] <= 1'b0;
            end
        end else if (ex_valid && ex_branch) begin
            // Update BHT (saturating counter)
            if (ex_taken) begin
                if (bht[ex_index] != 2'b11)
                    bht[ex_index] <= bht[ex_index] + 1;
            end else begin
                if (bht[ex_index] != 2'b00)
                    bht[ex_index] <= bht[ex_index] - 1;
            end
            
            // Update BTB
            btb_target[ex_index] <= ex_target;
            btb_valid[ex_index] <= 1'b1;
        end
    end

endmodule
