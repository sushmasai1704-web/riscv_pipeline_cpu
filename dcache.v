// ============================================================
// File   : rtl/dcache.v
// Description: Direct-mapped, write-through Data Cache
//              for a single-cycle RISC-V RV32I CPU.
//
//  Parameters
//  ----------
//  CACHE_SIZE   : total data bytes in cache (default 1 KB)
//  LINE_SIZE    : bytes per cache line      (default 16 B)
//  ADDR_WIDTH   : byte-address width        (default 32)
//
//  Address breakdown (for defaults):
//    [31:10] tag   (22 bits)
//    [ 9: 4] index (6  bits → 64 lines)
//    [ 3: 2] word  (2  bits → 4 words/line)
//    [ 1: 0] byte  (2  bits, ignored; accesses are aligned)
//
//  Memory interface (to backing store / "main memory"):
//    mem_req_valid / mem_req_ready / mem_req_addr  (read request)
//    mem_rdata_valid / mem_rdata                   (read response)
//    mem_wvalid / mem_waddr / mem_wdata / mem_wstrb (write-through)
// ============================================================

module dcache #(
    parameter CACHE_SIZE  = 1024,   // bytes
    parameter LINE_SIZE   = 16,     // bytes per line
    parameter ADDR_WIDTH  = 32
)(
    input  wire                  clk,
    input  wire                  rst_n,

    // --- CPU-side interface ---
    input  wire                  cpu_req,        // valid read/write request
    input  wire                  cpu_we,         // 1=write, 0=read
    input  wire [ADDR_WIDTH-1:0] cpu_addr,       // byte address
    input  wire [31:0]           cpu_wdata,      // write data
    input  wire [3:0]            cpu_wstrb,      // byte enable (write)
    output reg  [31:0]           cpu_rdata,      // read data
    output wire                  cpu_stall,      // stall CPU while miss refills

    // --- Memory-side interface (read: request/response) ---
    output reg                   mem_req_valid,  // read-miss request
    output reg  [ADDR_WIDTH-1:0] mem_req_addr,   // aligned to line
    input  wire                  mem_req_ready,  // memory accepted request
    input  wire                  mem_rdata_valid,// refill data valid
    input  wire [LINE_SIZE*8-1:0] mem_rdata,     // refill line data

    // --- Memory-side interface (write-through) ---
    output reg                   mem_wvalid,
    output reg  [ADDR_WIDTH-1:0] mem_waddr,
    output reg  [31:0]           mem_wdata,
    output reg  [3:0]            mem_wstrb
);

    // ----------------------------------------------------------
    // Derived parameters
    // ----------------------------------------------------------
    localparam NUM_LINES   = CACHE_SIZE / LINE_SIZE;          // 64
    localparam WORDS_PER_LINE = LINE_SIZE / 4;                // 4
    localparam BYTE_OFF_W  = $clog2(LINE_SIZE);               // 4
    localparam WORD_OFF_W  = $clog2(WORDS_PER_LINE);          // 2
    localparam INDEX_W     = $clog2(NUM_LINES);               // 6
    localparam TAG_W       = ADDR_WIDTH - INDEX_W - BYTE_OFF_W; // 22

    // ----------------------------------------------------------
    // Address field extraction
    // ----------------------------------------------------------
    wire [TAG_W-1:0]   req_tag   = cpu_addr[ADDR_WIDTH-1 : INDEX_W+BYTE_OFF_W];
    wire [INDEX_W-1:0] req_index = cpu_addr[INDEX_W+BYTE_OFF_W-1 : BYTE_OFF_W];
    wire [WORD_OFF_W-1:0] req_word = cpu_addr[BYTE_OFF_W-1 : 2];

    // ----------------------------------------------------------
    // Cache storage: tag, valid, data
    // ----------------------------------------------------------
    integer i;
    reg [TAG_W-1:0]            tag_array  [0:NUM_LINES-1];
    reg                        valid_array[0:NUM_LINES-1];
    reg [LINE_SIZE*8-1:0]      data_array [0:NUM_LINES-1];

    // ----------------------------------------------------------
    // Hit detection
    // ----------------------------------------------------------
    wire hit = cpu_req && valid_array[req_index] &&
               (tag_array[req_index] == req_tag);
    wire miss = cpu_req && !hit;

    // ----------------------------------------------------------
    // Read data mux (word within line)
    // ----------------------------------------------------------
    wire [LINE_SIZE*8-1:0] hit_line = data_array[req_index];

    always @(*) begin
        case (req_word)
            2'd0: cpu_rdata = hit_line[31:0];
            2'd1: cpu_rdata = hit_line[63:32];
            2'd2: cpu_rdata = hit_line[95:64];
            2'd3: cpu_rdata = hit_line[127:96];
            default: cpu_rdata = 32'hDEAD_BEEF;
        endcase
    end

    // ----------------------------------------------------------
    // FSM for miss handling
    // ----------------------------------------------------------
    localparam S_IDLE    = 2'd0;
    localparam S_MISS    = 2'd1;  // issue mem request
    localparam S_FILL    = 2'd2;  // wait for refill data
    localparam S_REPLAY  = 2'd3;  // one-cycle replay after fill

    reg [1:0] state, next_state;

    // Stall CPU when miss is being resolved
    // Only stall CPU for read misses (write-through writes are fire-and-forget)
    wire read_miss = cpu_req && !cpu_we && !hit;
    assign cpu_stall = (state != S_IDLE) || read_miss;

    // Capture miss address
    reg [ADDR_WIDTH-1:0] miss_addr_r;
    wire [ADDR_WIDTH-1:0] line_aligned_addr =
        {cpu_addr[ADDR_WIDTH-1:BYTE_OFF_W], {BYTE_OFF_W{1'b0}}};

    // FSM sequential
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) state <= S_IDLE;
        else        state <= next_state;
    end

    // FSM combinational
    always @(*) begin
        next_state = state;
        case (state)
            S_IDLE:  if (read_miss) next_state = S_MISS;
            S_MISS:  if (mem_req_ready)   next_state = S_FILL;
            S_FILL:  if (mem_rdata_valid) next_state = S_REPLAY;
            S_REPLAY:                     next_state = S_IDLE;
            default: next_state = S_IDLE;
        endcase
    end

    // ----------------------------------------------------------
    // Cache fill on refill data
    // ----------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin
            for (i = 0; i < NUM_LINES; i = i + 1) begin
                valid_array[i] <= 1'b0;
                tag_array[i]   <= {TAG_W{1'b0}};
                data_array[i]  <= {LINE_SIZE*8{1'b0}};
            end
        end else begin
            // Refill cache line on memory response
            if (state == S_FILL && mem_rdata_valid) begin
                data_array [miss_addr_r[INDEX_W+BYTE_OFF_W-1:BYTE_OFF_W]] <= mem_rdata;
                tag_array  [miss_addr_r[INDEX_W+BYTE_OFF_W-1:BYTE_OFF_W]] <=
                             miss_addr_r[ADDR_WIDTH-1:INDEX_W+BYTE_OFF_W];
                valid_array[miss_addr_r[INDEX_W+BYTE_OFF_W-1:BYTE_OFF_W]] <= 1'b1;
            end

            // Write-hit: update cache data (write-through to mem also)
            if (cpu_req && cpu_we && hit) begin
                if (cpu_wstrb[0]) data_array[req_index][req_word*32 +  7 -: 8] <= cpu_wdata[ 7:0];
                if (cpu_wstrb[1]) data_array[req_index][req_word*32 + 15 -: 8] <= cpu_wdata[15:8];
                if (cpu_wstrb[2]) data_array[req_index][req_word*32 + 23 -: 8] <= cpu_wdata[23:16];
                if (cpu_wstrb[3]) data_array[req_index][req_word*32 + 31 -: 8] <= cpu_wdata[31:24];
            end

            // Latch miss address
            if (read_miss && state == S_IDLE)
                miss_addr_r <= cpu_addr;
        end
    end

    // ----------------------------------------------------------
    // Memory request / write-through outputs
    // ----------------------------------------------------------
    always @(*) begin
        // Read-miss request
        mem_req_valid = (state == S_MISS);
        mem_req_addr  = {miss_addr_r[ADDR_WIDTH-1:BYTE_OFF_W], {BYTE_OFF_W{1'b0}}};

        // Write-through: forward every CPU write directly to memory
        mem_wvalid = cpu_req && cpu_we;
        mem_waddr  = cpu_addr;
        mem_wdata  = cpu_wdata;
        mem_wstrb  = cpu_wstrb;
    end

endmodule
