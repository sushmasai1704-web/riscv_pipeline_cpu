`timescale 1ns/1ps

module tb_reg_file;

    reg clk;
    reg we;
    reg [4:0] rs1, rs2, rd;
    reg [31:0] rd_data;
    wire [31:0] rs1_data, rs2_data;

    reg_file uut (
        .clk(clk),
        .we(we),
        .rs1_addr(rs1),
        .rs2_addr(rs2),
        .rd_addr(rd),
        .rd_data(rd_data),
        .rs1_data(rs1_data),
        .rs2_data(rs2_data)
    );

    always #5 clk = ~clk;

    initial begin
        clk = 0;
        we = 0;

        #10;
        we = 1; rd = 5'd1; rd_data = 32'd10;

        #10;
        we = 0;

        rs1 = 5'd1;
        #10;
        $display("x1 = %d (expected 10)", rs1_data);

        rs1 = 5'd0;
        #10;
        $display("x0 = %d (expected 0)", rs1_data);

        $finish;
    end

endmodule
