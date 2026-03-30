`timescale 1ns / 1ps
module icache (
    input         clk,
    input         rst,
    input  [31:0] cpu_addr,
    output wire [31:0] cpu_rdata,
    output wire        cpu_hit,
    input              cpu_req,
    output reg        mem_req,
    output reg [31:0] mem_addr,
    input      [127:0] mem_rdata,
    input              mem_ready
);
    reg [23:0] tags  [0:15];
    reg [31:0] data  [0:15][0:3];
    reg        valid [0:15];

    wire [1:0]  offset = cpu_addr[3:2];
    wire [3:0]  index  = cpu_addr[7:4];
    wire [23:0] tag    = cpu_addr[31:8];

    reg [31:0]  miss_addr;
    wire [1:0]  miss_offset = miss_addr[3:2];
    wire [3:0]  miss_index  = miss_addr[7:4];
    wire [23:0] miss_tag    = miss_addr[31:8];

    reg pending; // memory request in flight

    wire hit_wire = valid[index] && (tags[index] == tag);

    wire [31:0] fill_word = (miss_offset == 2'b00) ? mem_rdata[31:0]  :
                            (miss_offset == 2'b01) ? mem_rdata[63:32] :
                            (miss_offset == 2'b10) ? mem_rdata[95:64] :
                                                     mem_rdata[127:96];

    // Combinational outputs
    assign cpu_hit   = cpu_req && (hit_wire || mem_ready);
    assign cpu_rdata = mem_ready ? fill_word :
                       hit_wire  ? data[index][offset] : 32'h0;

    integer i;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (i = 0; i < 16; i = i+1) begin
                valid[i] <= 0; tags[i] <= 0;
            end
            mem_req   <= 0;
            mem_addr  <= 0;
            miss_addr <= 0;
            pending   <= 0;
        end else begin
            mem_req <= 0;

            // Only issue new request if none pending
            if (cpu_req && !hit_wire && !pending && !mem_ready) begin
                mem_req   <= 1;
                mem_addr  <= {cpu_addr[31:4], 4'b0};
                miss_addr <= cpu_addr;
                pending   <= 1;
            end

            // Fill on memory response
            if (mem_ready) begin
                data[miss_index][0] <= mem_rdata[31:0];
                data[miss_index][1] <= mem_rdata[63:32];
                data[miss_index][2] <= mem_rdata[95:64];
                data[miss_index][3] <= mem_rdata[127:96];
                tags[miss_index]    <= miss_tag;
                valid[miss_index]   <= 1;
                pending             <= 0;
            end
        end
    end
endmodule
