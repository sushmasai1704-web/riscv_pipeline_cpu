`timescale 1ns/1ps
module simple_cpu(
    input clk,
    input rst
);
    reg [31:0] PC;
    reg [31:0] regs[0:31];
    reg [31:0] instr_mem[0:31];
    integer i;

    // Pipeline registers
    reg [31:0] IF_ID_instr, IF_ID_PC;
    reg [4:0] ID_EX_rd;
    reg [31:0] ID_EX_PC;
    reg ID_EX_jal;
    reg [31:0] ID_EX_rs1_val, ID_EX_rs2_val;

    reg [4:0] EX_rd;
    reg [31:0] EX_PC, EX_out;
    reg EX_jal;

    reg [4:0] MEM_rd;
    reg [31:0] MEM_out;
    reg MEM_jal;

    reg [4:0] WB_rd;
    reg [31:0] WB_data;
    reg WB_jal;

    // -------------------- Initialization --------------------
    initial begin
        PC = 0;
        for(i=0;i<32;i=i+1) regs[i]=0;
        for(i=0;i<32;i=i+1) instr_mem[i]=0;

        // Sample instructions
        instr_mem[0]=32'b00000000100000000000001011101111; // JAL x5,+8
        instr_mem[1]=32'b00000000010101010000001110110011; // ADD x6,x5,x5
        instr_mem[2]=32'b00000000011001100000010000010011; // ADDI x8,x6,6

        IF_ID_instr=0; IF_ID_PC=0;
        ID_EX_rd=0; ID_EX_PC=0; ID_EX_jal=0;
        ID_EX_rs1_val=0; ID_EX_rs2_val=0;
        EX_rd=0; EX_PC=0; EX_jal=0; EX_out=0;
        MEM_rd=0; MEM_out=0; MEM_jal=0;
        WB_rd=0; WB_data=0; WB_jal=0;
    end

    // -------------------- Forwarding wires (combinational) --------------------
    wire [31:0] rs1_val = (IF_ID_instr[19:15]==EX_rd && EX_rd!=0) ? EX_out :
                           (IF_ID_instr[19:15]==MEM_rd && MEM_rd!=0) ? MEM_out :
                           regs[IF_ID_instr[19:15]];

    wire [31:0] rs2_val = (IF_ID_instr[24:20]==EX_rd && EX_rd!=0) ? EX_out :
                           (IF_ID_instr[24:20]==MEM_rd && MEM_rd!=0) ? MEM_out :
                           regs[IF_ID_instr[24:20]];

    // -------------------- Pipeline --------------------
    always @(posedge clk) begin
        if(rst) begin
            PC <= 0;
            IF_ID_instr<=0; IF_ID_PC<=0;
            ID_EX_rd<=0; ID_EX_PC<=0; ID_EX_jal<=0;
            ID_EX_rs1_val<=0; ID_EX_rs2_val<=0;
            EX_rd<=0; EX_PC<=0; EX_jal<=0; EX_out<=0;
            MEM_rd<=0; MEM_out<=0; MEM_jal<=0;
            WB_rd<=0; WB_data<=0; WB_jal<=0;
            for(i=0;i<32;i=i+1) regs[i]=0;
        end
        else begin
            // -------- WB stage --------
            if(WB_rd != 0)
                regs[WB_rd] <= WB_data;

            // -------- MEM stage --------
            MEM_rd <= EX_rd;
            MEM_out <= EX_out;
            MEM_jal <= EX_jal;

            // -------- EX stage --------
            EX_rd <= ID_EX_rd;
            EX_PC <= ID_EX_PC;
            EX_jal <= ID_EX_jal;
            EX_out <= EX_jal ? ID_EX_PC + 4 : ID_EX_rs1_val + ID_EX_rs2_val;

            // -------- ID stage --------
            ID_EX_rd <= IF_ID_instr[11:7];               // rd
            ID_EX_PC <= IF_ID_PC;
            ID_EX_jal <= (IF_ID_instr[6:0]==7'b1101111); // JAL opcode
            ID_EX_rs1_val <= rs1_val;
            ID_EX_rs2_val <= rs2_val;

            // -------- IF stage --------
            IF_ID_instr <= instr_mem[PC>>2];
            IF_ID_PC <= PC;

            // -------- PC update --------
            PC <= EX_jal ? EX_PC + 8 : PC + 4;

            // -------- WB stage assignment --------
            WB_rd <= MEM_rd;
            WB_data <= MEM_out;
            WB_jal <= MEM_jal;
        end
    end

    // -------------------- Monitor --------------------
    always @(posedge clk) begin
        if(!rst)
            $display("PC=%d, x5=%d, x6=%d, x8=%d", PC, regs[5], regs[6], regs[8]);
    end

endmodule
