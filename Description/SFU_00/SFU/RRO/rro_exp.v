//------------------------------------------------------------------------------
// Project : RRO IEEE754 (Verilog rewrite)
// File    : rro.v
// Note    : Simplified to keep ONLY the exp2 preprocessing path. Port `input`
//           is renamed to `input_data` to avoid the Verilog keyword conflict.
//------------------------------------------------------------------------------

module rro (
    input  wire [31:0] input_data,
    output wire [31:0] Result
);

    // Exp2 preprocessing signals
    wire        s_too_big_exponent;
    wire [7:0]  s_exp2_shift;
    wire [31:0] s_exp2_fixed_point;
    wire [31:0] s_exp2_sign_ext;
    wire [31:0] s_exp2_cmp;
    wire [31:0] s_exp2_adjs;
    reg  [31:0] s_exp2_final_result;

    // -------------------------------------------------------------------------
    // exp2(x) range reduction and special-case handling
    // -------------------------------------------------------------------------
    assign s_too_big_exponent = (input_data[30:23] > 8'd133);
    assign s_exp2_shift       = 8'd133 - input_data[30:23];
    assign s_exp2_fixed_point = ({3'b001, input_data[22:0], 6'b000000} >> s_exp2_shift);
    assign s_exp2_sign_ext    = {32{input_data[31]}};
    assign s_exp2_cmp         = s_exp2_fixed_point ^ s_exp2_sign_ext;
    assign s_exp2_adjs        = input_data[31] ? (s_exp2_cmp + 32'd1) : s_exp2_cmp;

    // Priority chain replicating VHDL with NaN/Inf/overflow/zero handling
    always @(*) begin
        if (input_data == 32'h7f800000) begin
            // +Inf
            s_exp2_final_result = 32'b1_00001111_00000000000000000000000;
        end else if (input_data == 32'hff800000) begin
            // -Inf
            s_exp2_final_result = 32'b1_11110000_00000000000000000000000;
        end else if ((input_data[30:23] == 8'hFF) && (input_data[22:0] != 23'b0)) begin
            // NaN
            s_exp2_final_result = {1'b1, 8'hFF, input_data[22:0]};
        end else if (s_too_big_exponent && !input_data[31]) begin
            // Positive overflow
            s_exp2_final_result = 32'b1_00001111_00000000000000000000000;
        end else if (s_too_big_exponent && input_data[31]) begin
            // Negative overflow
            s_exp2_final_result = 32'b1_11110000_00000000000000000000000;
        end else if ((input_data == 32'h00000000) || (input_data[30:23] == 8'h00)) begin
            // Zero or subnormal
            s_exp2_final_result = 32'b1_00000000_00000000000000000000000;
        end else begin
            // Normal path
            s_exp2_final_result = {1'b0, s_exp2_adjs[30:0]};
        end
    end

    // -------------------------------------------------------------------------
    // -------------------------------------------------------------------------
    // Output: only exp2 path retained
    // -------------------------------------------------------------------------
    assign Result = s_exp2_final_result;
endmodule
