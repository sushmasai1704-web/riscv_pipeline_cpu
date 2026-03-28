module data_mem(
    input clk,
    input mem_write,
    input mem_read,
    input [31:0] addr,
    input [31:0] write_data,
    output reg [31:0] read_data
);

    reg [31:0] memory [0:255];

    always @(posedge clk) begin
        // STORE
        if (mem_write)
            memory[addr] <= write_data;

        // LOAD
        if (mem_read)
            read_data <= memory[addr];
    end

endmodule
