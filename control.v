// ============================================================
// File   : rtl/control.v
// Description: Main control unit for RISC-V RV32I single-cycle
//              Decodes opcode → control signals
// ============================================================

module control (
    input  wire [6:0] opcode,       // instruction[6:0]
    input  wire [2:0] funct3,       // instruction[14:12]
    input  wire [6:0] funct7,       // instruction[31:25]

    // Register file
    output reg        reg_write,    // Enable RF write
    // Immediate / ALU source
    output reg        alu_src,      // 0=RS2, 1=Immediate
    // ALU control
    output reg  [3:0] alu_ctrl,     // ALU operation
    // Memory
    output reg        mem_read,     // Enable data-memory read
    output reg        mem_write,    // Enable data-memory write
    output reg  [1:0] mem_size,     // 00=byte,01=half,10=word
    output reg        mem_unsigned, // 1=zero-extend load
    // Write-back mux
    output reg  [1:0] wb_sel,       // 00=ALU,01=MEM,10=PC+4
    // Branch / Jump
    output reg        branch,       // Conditional branch
    output reg        jal,          // JAL
    output reg        jalr,         // JALR
    // Upper-immediate / AUIPC
    output reg        lui,          // LUI
    output reg        auipc         // AUIPC
);

    // ----------------------------------------------------------
    // Opcode map (RV32I)
    // ----------------------------------------------------------
    localparam OP_R      = 7'b0110011; // R-type
    localparam OP_I_ALU  = 7'b0010011; // I-type ALU
    localparam OP_LOAD   = 7'b0000011; // Load
    localparam OP_STORE  = 7'b0100011; // Store
    localparam OP_BRANCH = 7'b1100011; // Branch
    localparam OP_JAL    = 7'b1101111; // JAL
    localparam OP_JALR   = 7'b1100111; // JALR
    localparam OP_LUI    = 7'b0110111; // LUI
    localparam OP_AUIPC  = 7'b0010111; // AUIPC

    // ALU ctrl codes (must match alu.v)
    localparam ALU_ADD  = 4'b0000;
    localparam ALU_SUB  = 4'b0001;
    localparam ALU_AND  = 4'b0010;
    localparam ALU_OR   = 4'b0011;
    localparam ALU_XOR  = 4'b0100;
    localparam ALU_SLL  = 4'b0101;
    localparam ALU_SRL  = 4'b0110;
    localparam ALU_SRA  = 4'b0111;
    localparam ALU_SLT  = 4'b1000;
    localparam ALU_SLTU = 4'b1001;
    localparam ALU_LUI  = 4'b1010;
    localparam ALU_AUIPC= 4'b1011;

    // ----------------------------------------------------------
    // Helper: decode ALU op for R-type and I-ALU
    // ----------------------------------------------------------
    function [3:0] decode_alu;
        input [2:0] f3;
        input [6:0] f7;
        input       is_r;   // 1=R-type (SUB/SRA possible)
        begin
            case (f3)
                3'b000: decode_alu = (is_r && f7[5]) ? ALU_SUB : ALU_ADD;
                3'b001: decode_alu = ALU_SLL;
                3'b010: decode_alu = ALU_SLT;
                3'b011: decode_alu = ALU_SLTU;
                3'b100: decode_alu = ALU_XOR;
                3'b101: decode_alu = (f7[5]) ? ALU_SRA : ALU_SRL;
                3'b110: decode_alu = ALU_OR;
                3'b111: decode_alu = ALU_AND;
                default: decode_alu = ALU_ADD;
            endcase
        end
    endfunction

    // ----------------------------------------------------------
    // Control logic
    // ----------------------------------------------------------
    always @(*) begin
        // Defaults (safe / NOP)
        reg_write    = 1'b0;
        alu_src      = 1'b0;
        alu_ctrl     = ALU_ADD;
        mem_read     = 1'b0;
        mem_write    = 1'b0;
        mem_size     = 2'b10;   // word
        mem_unsigned = 1'b0;
        wb_sel       = 2'b00;   // ALU result
        branch       = 1'b0;
        jal          = 1'b0;
        jalr         = 1'b0;
        lui          = 1'b0;
        auipc        = 1'b0;

        case (opcode)
            // --------------------------------------------------
            // R-type: ADD SUB AND OR XOR SLL SRL SRA SLT SLTU
            // --------------------------------------------------
            OP_R: begin
                reg_write = 1'b1;
                alu_src   = 1'b0;
                alu_ctrl  = decode_alu(funct3, funct7, 1'b1);
                wb_sel    = 2'b00;
            end

            // --------------------------------------------------
            // I-type ALU: ADDI ANDI ORI XORI SLTI SLTIU SLLI SRLI SRAI
            // --------------------------------------------------
            OP_I_ALU: begin
                reg_write = 1'b1;
                alu_src   = 1'b1;
                alu_ctrl  = decode_alu(funct3, funct7, 1'b0);
                wb_sel    = 2'b00;
            end

            // --------------------------------------------------
            // Load: LB LH LW LBU LHU
            // --------------------------------------------------
            OP_LOAD: begin
                reg_write    = 1'b1;
                alu_src      = 1'b1;
                alu_ctrl     = ALU_ADD;
                mem_read     = 1'b1;
                wb_sel       = 2'b01;   // memory data
                // mem_size / mem_unsigned from funct3
                case (funct3)
                    3'b000: begin mem_size = 2'b00; mem_unsigned = 1'b0; end // LB
                    3'b001: begin mem_size = 2'b01; mem_unsigned = 1'b0; end // LH
                    3'b010: begin mem_size = 2'b10; mem_unsigned = 1'b0; end // LW
                    3'b100: begin mem_size = 2'b00; mem_unsigned = 1'b1; end // LBU
                    3'b101: begin mem_size = 2'b01; mem_unsigned = 1'b1; end // LHU
                    default: begin mem_size = 2'b10; mem_unsigned = 1'b0; end
                endcase
            end

            // --------------------------------------------------
            // Store: SB SH SW
            // --------------------------------------------------
            OP_STORE: begin
                alu_src   = 1'b1;
                alu_ctrl  = ALU_ADD;
                mem_write = 1'b1;
                case (funct3)
                    3'b000: mem_size = 2'b00; // SB
                    3'b001: mem_size = 2'b01; // SH
                    3'b010: mem_size = 2'b10; // SW
                    default: mem_size = 2'b10;
                endcase
            end

            // --------------------------------------------------
            // Branch: BEQ BNE BLT BGE BLTU BGEU
            // --------------------------------------------------
            OP_BRANCH: begin
                alu_src  = 1'b0;
                alu_ctrl = ALU_SUB;
                branch   = 1'b1;
            end

            // --------------------------------------------------
            // JAL
            // --------------------------------------------------
            OP_JAL: begin
                reg_write = 1'b1;
                alu_ctrl  = ALU_ADD;
                wb_sel    = 2'b10;  // PC+4
                jal       = 1'b1;
            end

            // --------------------------------------------------
            // JALR
            // --------------------------------------------------
            OP_JALR: begin
                reg_write = 1'b1;
                alu_src   = 1'b1;
                alu_ctrl  = ALU_ADD;
                wb_sel    = 2'b10;  // PC+4
                jalr      = 1'b1;
            end

            // --------------------------------------------------
            // LUI
            // --------------------------------------------------
            OP_LUI: begin
                reg_write = 1'b1;
                alu_src   = 1'b1;
                alu_ctrl  = ALU_LUI;
                wb_sel    = 2'b00;
                lui       = 1'b1;
            end

            // --------------------------------------------------
            // AUIPC
            // --------------------------------------------------
            OP_AUIPC: begin
                reg_write = 1'b1;
                alu_src   = 1'b1;
                alu_ctrl  = ALU_AUIPC;
                wb_sel    = 2'b00;
                auipc     = 1'b1;
            end

            default: ; // NOP / illegal → keep defaults
        endcase
    end

endmodule
