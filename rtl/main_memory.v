`timescale 1ns / 1ps

// Simulated main memory with configurable latency
// 1024 words = 4KB, latency = 4 cycles (simulates DRAM)
module main_memory #(
    parameter DEPTH   = 1024,
    parameter LATENCY = 4
)(
    input         clk,
    input         rst,

    // Instruction port (read only)
    input         ireq,           // request
    input  [31:0] iaddr,          // byte address
    output reg [127:0] idata,     // 4-word cache line
    output reg    iready,         // data valid

    // Data port (read/write)
    input         dreq,
    input         dwrite,
    input  [31:0] daddr,
    input  [127:0] dwdata,        // write full cache line
    input  [3:0]  dwe,            // word write enable within line
    output reg [127:0] drdata,    // 4-word cache line
    output reg    dready
);

    reg [31:0] mem [0:DEPTH-1];
    initial $readmemh("program.hex", mem);

    // ── Instruction port ─────────────────────────────────────
    reg [3:0] icnt;
    reg       ibusy;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            icnt   <= 0; ibusy <= 0;
            iready <= 0; idata <= 0;
        end else begin
            iready <= 0;
            if (ireq && !ibusy) begin
                ibusy <= 1; icnt <= 0;
            end else if (ibusy) begin
                if (icnt == LATENCY-1) begin
                    // Return 4-word cache line aligned to line boundary
                    idata[31:0]   <= mem[{iaddr[31:4], 2'b00}];
                    idata[63:32]  <= mem[{iaddr[31:4], 2'b01}];
                    idata[95:64]  <= mem[{iaddr[31:4], 2'b10}];
                    idata[127:96] <= mem[{iaddr[31:4], 2'b11}];
                    iready <= 1; ibusy <= 0;
                end else begin
                    icnt <= icnt + 1;
                end
            end
        end
    end

    // ── Data port ────────────────────────────────────────────
    reg [3:0] dcnt;
    reg       dbusy;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            dcnt   <= 0; dbusy <= 0;
            dready <= 0; drdata <= 0;
        end else begin
            dready <= 0;
            if (dreq && !dbusy) begin
                dbusy <= 1; dcnt <= 0;
            end else if (dbusy) begin
                if (dcnt == LATENCY-1) begin
                    if (dwrite) begin
                        if (dwe[0]) mem[{daddr[31:4], 2'b00}] <= dwdata[31:0];
                        if (dwe[1]) mem[{daddr[31:4], 2'b01}] <= dwdata[63:32];
                        if (dwe[2]) mem[{daddr[31:4], 2'b10}] <= dwdata[95:64];
                        if (dwe[3]) mem[{daddr[31:4], 2'b11}] <= dwdata[127:96];
                    end else begin
                        drdata[31:0]   <= mem[{daddr[31:4], 2'b00}];
                        drdata[63:32]  <= mem[{daddr[31:4], 2'b01}];
                        drdata[95:64]  <= mem[{daddr[31:4], 2'b10}];
                        drdata[127:96] <= mem[{daddr[31:4], 2'b11}];
                    end
                    dready <= 1; dbusy <= 0;
                end else begin
                    dcnt <= dcnt + 1;
                end
            end
        end
    end

endmodule
