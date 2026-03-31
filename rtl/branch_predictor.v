module branch_predictor #(
    parameter INDEX_BITS = 8  // 256-entry BHT
)(
    input wire clk,
    input wire rst_n,
    
    // Prediction request (IF stage)
    input wire [31:0] pc,           // Current PC to predict
    input wire predict_req,           // Valid prediction request
    
    output wire predict_taken,        // Prediction: 1 = taken, 0 = not taken
    output wire [31:0] predict_target, // Predicted target (if taken)
    output wire predict_valid,        // Prediction is valid (PC in BTB)
    
    // Update (EX stage, when branch resolves)
    input wire [31:0] ex_pc,          // PC of resolving branch
    input wire ex_branch,             // This was a branch instruction
    input wire ex_taken,              // Actual outcome: taken or not
    input wire [31:0] ex_target,      // Actual target (if taken)
    input wire ex_valid               // Update is valid
);

// Internal: 2-bit saturating counters [1:0]
// 00: Strongly Not Taken, 01: Weakly Not Taken
// 10: Weakly Taken, 11: Strongly Taken

reg [1:0] bht [0:(1<<INDEX_BITS)-1];  // Branch History Table

// BTB: Branch Target Buffer
// Stores target PC for taken branches
reg [31:0] btb_pc   [0:(1<<INDEX_BITS)-1];    // Tag (full PC or partial)
reg [31:0] btb_target[0:(1<<INDEX_BITS)-1];   // Target address
reg        btb_valid [0:(1<<INDEX_BITS)-1];   // Entry valid

wire [INDEX_BITS-1:0] index = pc[INDEX_BITS+1:2];  // Word-aligned, drop lower bits
wire [INDEX_BITS-1:0] ex_index = ex_pc[INDEX_BITS+1:2];

// Prediction logic
assign predict_valid = btb_valid[index] && (btb_pc[index] == pc);
assign predict_taken = predict_valid && (bht[index][1] == 1'b1);  // MSB determines
assign predict_target = btb_target[index];

// Update logic (sequential)
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // Reset all entries to Weakly Not Taken (01)
        integer i;
        for (i = 0; i < (1<<INDEX_BITS); i = i + 1) begin
            bht[i] <= 2'b01;
            btb_valid[i] <= 1'b0;
        end
    end else if (ex_valid && ex_branch) begin
        // Update BHT (2-bit saturating counter)
        if (ex_taken) begin
            if (bht[ex_index] != 2'b11)
                bht[ex_index] <= bht[ex_index] + 1;
        end else begin
            if (bht[ex_index] != 2'b00)
                bht[ex_index] <= bht[ex_index] - 1;
        end
        
        // Update BTB (only on taken branches, or always for allocation)
        btb_pc[ex_index] <= ex_pc;
        btb_target[ex_index] <= ex_target;
        btb_valid[ex_index] <= 1'b1;
    end
end

endmodule
