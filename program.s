.section .text
.globl _start
_start:
    addi x1,  x0, 10
    addi x2,  x0, 20
    add  x3,  x1, x2
    sub  x4,  x3, x1
    slt  x6,  x1, x2
    slt  x7,  x2, x1
    slti x8,  x1, 15
    slti x9,  x1, 5
    addi x28, x0, -80
    srai x29, x28, 3
    lui  x30, 0xABCDE
    auipc x31, 1
    sw x3,   160(x0)
    sw x4,   164(x0)
    sw x6,   168(x0)
    sw x7,   172(x0)
    sw x8,   176(x0)
    sw x9,   180(x0)
    sw x29,  184(x0)
    sw x30,  188(x0)
    sw x31,  192(x0)
    addi x11, x0, 0xBB
    beq  x0,  x0, beq_taken
    addi x11, x0, 0
beq_taken:
    sw x11,  196(x0)
    addi x11, x0, 0xCC
    addi x12, x0, 1
    bne  x0,  x12, bne_taken
    addi x11, x0, 0
bne_taken:
    sw x11,  200(x0)
    nop
    nop
    nop
    jal  x13, jal_target
jal_back:
    sw x13,  204(x0)
    nop
    nop
    jalr x14, x13, 0
jalr_back:
    sw x14,  208(x0)
halt:
    beq x0, x0, halt
jal_target:
    jalr x0, x13, 0
