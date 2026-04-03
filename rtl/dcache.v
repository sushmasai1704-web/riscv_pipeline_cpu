`timescale 1ns / 1ps
module dcache (
    input         clk, rst,
    input  [31:0] cpu_addr,
    input  [31:0] cpu_wdata,
    input         cpu_we,
    input         cpu_req,
    output reg [31:0] cpu_rdata,
    output wire   cpu_hit,
    output reg        mem_req,
    output reg        mem_write,
    output reg [31:0] mem_addr,
    output reg [127:0] mem_wdata,
    output reg [3:0]  mem_we,
    input      [127:0] mem_rdata,
    input             mem_ready
);
    reg [23:0] tags  [0:15];
    reg [31:0] data  [0:15][0:3];
    reg        valid [0:15];
    reg        dirty [0:15];

    wire [1:0]  offset = cpu_addr[3:2];
    wire [3:0]  index  = cpu_addr[7:4];
    wire [23:0] tag    = cpu_addr[31:8];
    wire hit_wire = valid[index] && (tags[index] == tag);

    reg [31:0] miss_addr;
    reg [31:0] miss_wdata;
    reg        miss_we;
    wire [1:0]  miss_offset = miss_addr[3:2];
    wire [3:0]  miss_index  = miss_addr[7:4];
    wire [23:0] miss_tag    = miss_addr[31:8];

    reg pending;
    reg [1:0] state;
    localparam IDLE=0, FETCH=1, WB=2;

    assign cpu_hit = (state == IDLE  && cpu_req && hit_wire) ||
                     (state == FETCH && mem_ready);

    integer i;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (i=0;i<16;i=i+1) begin
                valid[i] <= 0; dirty[i] <= 0; tags[i] <= 0;
            end
            mem_req<=0; mem_write<=0; cpu_rdata<=0;
            state<=IDLE; pending<=0;
            miss_addr<=0; miss_wdata<=0; miss_we<=0;
        end else begin
            mem_req   <= 0;
            mem_write <= 0;
            case (state)
                IDLE: begin
                    if (cpu_req && !pending) begin
                        if (hit_wire) begin
                            if (cpu_we) begin
                                data[index][offset] <= cpu_wdata;
                                dirty[index]        <= 1;
                            end else begin
                                cpu_rdata <= data[index][offset];
                            end
                        end else begin
                            miss_addr  <= cpu_addr;
                            miss_wdata <= cpu_wdata;
                            miss_we    <= cpu_we;
                            pending    <= 1;
                            if (dirty[index]) begin
                                mem_req           <= 1;
                                mem_write         <= 1;
                                mem_addr          <= {tags[index], index, 4'b0};
                                mem_wdata[31:0]   <= data[index][0];
                                mem_wdata[63:32]  <= data[index][1];
                                mem_wdata[95:64]  <= data[index][2];
                                mem_wdata[127:96] <= data[index][3];
                                mem_we            <= 4'b1111;
                                state             <= WB;
                            end else begin
                                mem_req   <= 1;
                                mem_write <= 0;
                                mem_addr  <= {cpu_addr[31:4], 4'b0};
                                mem_we    <= 4'b0000;
                                state     <= FETCH;
                            end
                        end
                    end
                end
                FETCH: begin
                    if (mem_ready) begin
                        data[miss_index][0] <= mem_rdata[31:0];
                        data[miss_index][1] <= mem_rdata[63:32];
                        data[miss_index][2] <= mem_rdata[95:64];
                        data[miss_index][3] <= mem_rdata[127:96];
                        tags[miss_index]    <= miss_tag;
                        valid[miss_index]   <= 1;
                        dirty[miss_index]   <= 0;
                        if (miss_we) begin
                            data[miss_index][miss_offset] <= miss_wdata;
                            dirty[miss_index]             <= 1;
                        end else begin
                            cpu_rdata <=
                                (miss_offset==0) ? mem_rdata[31:0]   :
                                (miss_offset==1) ? mem_rdata[63:32]  :
                                (miss_offset==2) ? mem_rdata[95:64]  :
                                                   mem_rdata[127:96] ;
                        end
                        pending <= 0;
                        state   <= IDLE;
                    end
                end
                WB: begin
                    if (mem_ready) begin
                        dirty[miss_index] <= 0;
                        mem_req   <= 1;
                        mem_write <= 0;
                        mem_addr  <= {miss_addr[31:4], 4'b0};
                        mem_we    <= 4'b0000;
                        state     <= FETCH;
                    end
                end
            endcase
        end
    end
endmodule
