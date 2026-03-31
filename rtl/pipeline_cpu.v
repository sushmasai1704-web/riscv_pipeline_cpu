module pipeline_cpu(
    input clk
);

// Example ALU block (you must place this inside module, not at top)

always @(*) begin
    case(alu_control)
        4'b0000: result = a + b;
        4'b0001: result = a - b;
        4'b0010: result = a & b; // AND
        4'b0011: result = a | b; // OR
        default: result = 0;
    endcase
end
