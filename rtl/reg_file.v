module reg_file #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 5
)(
    input clk,
    input we,

    input [ADDR_WIDTH-1:0] rs1_addr,
    input [ADDR_WIDTH-1:0] rs2_addr,
    input [ADDR_WIDTH-1:0] rd_addr,

    input [DATA_WIDTH-1:0] rd_data,

    output [DATA_WIDTH-1:0] rs1_data,
    output [DATA_WIDTH-1:0] rs2_data
);

    reg [DATA_WIDTH-1:0] regs [0:31];

    // Read
    assign rs1_data = (rs1_addr == 0) ? 0 : regs[rs1_addr];
    assign rs2_data = (rs2_addr == 0) ? 0 : regs[rs2_addr];

    // Write
    always @(posedge clk) begin
        if (we && rd_addr != 0)
            regs[rd_addr] <= rd_data;
    end

endmodule
