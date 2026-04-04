`timescale 1ns/1ps
module simple_cpu(
    input clk,
    input rst
);
    reg [31:0] PC;
    reg [31:0] regs[0:31];
    reg [31:0] instr_mem[0:31];
    integer i;

    reg [31:0] IF_ID_instr, IF_ID_PC;
    reg [4:0]  ID_EX_rd, ID_EX_rs1, ID_EX_rs2;
    reg [31:0] ID_EX_rs1_val, ID_EX_rs2_val;
    reg [31:0] ID_EX_imm;
    reg        ID_EX_addi;
    reg [4:0]  EX_MEM_rd;
    reg [31:0] EX_MEM_out;
    reg [4:0]  MEM_WB_rd;
    reg [31:0] MEM_WB_data;

    function [31:0] ADDI;
        input [4:0] rd, rs1; input [11:0] imm;
        ADDI = {imm, rs1, 3'b000, rd, 7'b0010011};
    endfunction
    function [31:0] ADD;
        input [4:0] rd, rs1, rs2;
        ADD = {7'b0000000, rs2, rs1, 3'b000, rd, 7'b0110011};
    endfunction

    initial begin
        PC = 0;
        for(i=0;i<32;i=i+1) regs[i]=0;
        for(i=0;i<32;i=i+1) instr_mem[i]=0;
        instr_mem[0]  = ADDI(5'd1,  5'd0, 12'd10);
        instr_mem[1]  = ADDI(5'd2,  5'd0, 12'd20);
        instr_mem[2]  = ADDI(5'd3,  5'd0, 12'd5);
        instr_mem[3]  = ADD (5'd4,  5'd1, 5'd2);
        instr_mem[4]  = ADD (5'd5,  5'd4, 5'd3);
        instr_mem[5]  = ADDI(5'd6,  5'd5, 12'd100);
        instr_mem[6]  = ADD (5'd7,  5'd1, 5'd3);
        instr_mem[7]  = ADDI(5'd8,  5'd7, 12'd7);
        instr_mem[8]  = ADD (5'd9,  5'd6, 5'd8);
        instr_mem[9]  = ADDI(5'd10, 5'd0, 12'd42);
        instr_mem[10] = ADDI(5'd0,  5'd0, 12'd0);
        IF_ID_instr=0; IF_ID_PC=0;
        ID_EX_rd=0; ID_EX_rs1=0; ID_EX_rs2=0;
        ID_EX_rs1_val=0; ID_EX_rs2_val=0; ID_EX_imm=0; ID_EX_addi=0;
        EX_MEM_rd=0; EX_MEM_out=0;
        MEM_WB_rd=0; MEM_WB_data=0;
    end

    wire [4:0]  dec_rd   = IF_ID_instr[11:7];
    wire [4:0]  dec_rs1  = IF_ID_instr[19:15];
    wire [4:0]  dec_rs2  = IF_ID_instr[24:20];
    wire [31:0] dec_imm  = {{20{IF_ID_instr[31]}}, IF_ID_instr[31:20]};
    wire        dec_addi = (IF_ID_instr[6:0] == 7'b0010011);

    wire [31:0] ex_rs1 =
        (ID_EX_rs1 != 0 && ID_EX_rs1 == EX_MEM_rd)  ? EX_MEM_out  :
        (ID_EX_rs1 != 0 && ID_EX_rs1 == MEM_WB_rd)  ? MEM_WB_data :
        ID_EX_rs1_val;
    wire [31:0] ex_rs2 =
        (ID_EX_rs2 != 0 && ID_EX_rs2 == EX_MEM_rd)  ? EX_MEM_out  :
        (ID_EX_rs2 != 0 && ID_EX_rs2 == MEM_WB_rd)  ? MEM_WB_data :
        ID_EX_rs2_val;
    wire [31:0] alu_out = ID_EX_addi ? ex_rs1 + ID_EX_imm : ex_rs1 + ex_rs2;

    wire [31:0] id_rs1 =
        (dec_rs1 != 0 && dec_rs1 == MEM_WB_rd) ? MEM_WB_data : regs[dec_rs1];
    wire [31:0] id_rs2 =
        (dec_rs2 != 0 && dec_rs2 == MEM_WB_rd) ? MEM_WB_data : regs[dec_rs2];

    always @(posedge clk) begin
        if(rst) begin
            PC <= 0;
            IF_ID_instr<=0; IF_ID_PC<=0;
            ID_EX_rd<=0; ID_EX_rs1<=0; ID_EX_rs2<=0;
            ID_EX_rs1_val<=0; ID_EX_rs2_val<=0; ID_EX_imm<=0; ID_EX_addi<=0;
            EX_MEM_rd<=0; EX_MEM_out<=0;
            MEM_WB_rd<=0; MEM_WB_data<=0;
            for(i=0;i<32;i=i+1) regs[i]=0;
        end
        else begin
            if(MEM_WB_rd != 0) regs[MEM_WB_rd] <= MEM_WB_data;
            MEM_WB_rd   <= EX_MEM_rd;
            MEM_WB_data <= EX_MEM_out;
            EX_MEM_rd   <= ID_EX_rd;
            EX_MEM_out  <= alu_out;
            ID_EX_rd      <= dec_rd;
            ID_EX_rs1     <= dec_rs1;
            ID_EX_rs2     <= dec_rs2;
            ID_EX_rs1_val <= id_rs1;
            ID_EX_rs2_val <= id_rs2;
            ID_EX_imm     <= dec_imm;
            ID_EX_addi    <= dec_addi;
            IF_ID_instr <= instr_mem[PC>>2];
            IF_ID_PC    <= PC;
            PC          <= PC + 4;
        end
    end

    always @(posedge clk) begin
        if(!rst)
            $display("t=%4t PC=%3d | x1=%3d x2=%3d x3=%3d x4=%3d x5=%3d x6=%3d x7=%3d x8=%3d x9=%3d x10=%3d",
                $time, PC, regs[1], regs[2], regs[3], regs[4],
                regs[5], regs[6], regs[7], regs[8], regs[9], regs[10]);
    end
endmodule
