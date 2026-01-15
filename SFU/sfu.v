//-----------------------------------------------------------------------------
// Project         :   SFU IEEE754
// File Name       :   sfu.v
// Title           :   Special Function Unit  
//-----------------------------------------------------------------------------
// Description     :   This unit performs the floating point operations
//                     sin(x), cos(x), rsqrt(x), log2(x), exp2(x), 1/x, and sqrt(x), using
//                     IEEE754 standard and operational compliant with GPU G80
//                     architecture
//-----------------------------------------------------------------------------
// Universidad Pedagogica y Tecnologica de Colombia
//-----------------------------------------------------------------------------

module sfu (
    input  wire [31:0] src1_i,   // IEEE754 input data
    input  wire [2:0]  selop_i,   // Operation selection
    output reg  [31:0] Result_o  // IEEE754 result data output
);

    // Internal Signals Declaration
    wire [22:0] s_in_mantiza;
    wire [7:0]  s_in_exponent;
    wire        s_in_sign;

    wire [31:0] s_in_sin_cos_adj;
    wire [23:0] s_half_pi_minus_x;
    wire [1:0]  s_in_sin_cos_quad;
    wire [31:0] s_in_data_inter;
    wire [2:0]  s_in_oper_select;

    wire [42:0] s_Res_Quad_int_o;

    // Log2 signals declaration before normalization
    wire        s_log2_Exp_eq_zero;
    wire        s_log2_sign;
    wire        s_log2_sign_neg;
    wire [6:0]  s_log2_exp_sign_ext;
    wire [48:0] s_log2_fix_sign_ext;
    wire [6:0]  s_log2_int_part_xor;
    wire [7:0]  s_log2_int_part;
    wire [48:0] s_log2_Fix_point_xor;
    wire [48:0] s_log2_Fix_point_t;
    wire [48:0] s_log2_Fix_point;
    wire [83:0] s_log2_mult_Mx;
    wire [48:0] s_log2_res_unorm;

    // Normalization signals
    wire [63:0] s_in_norm;
    wire [5:0]  s_num_of_Zeros;
    wire        s_MSB_zeros;
    wire [8:0]  s_exp_norm;
    wire [48:0] s_res_norm;
    wire [22:0] s_res_mantiza;

    wire        s_rounding_even;
    wire [8:0]  s_rounding_exp;
    wire [24:0] s_mantiza_rounding;
    wire [24:0] s_rounding_mantiza;

    // Exponent correction signals
    wire [8:0]  s_denorm_exp_Ex;
    wire [8:0]  s_Ex_1;
    wire [8:0]  s_Ex_1_srl;
    wire [8:0]  s_Ex_srl;
    wire [8:0]  s_rsqrt_Ex_1_srl_t;
    wire [8:0]  s_rcp_Exp_t;
    wire [8:0]  s_rsqrt_Ex_srl_t;
    wire [8:0]  s_rsqrt_Ex_t;
    reg  [8:0]  s_final_exp_mux;
    wire [8:0]  s_final_exp_t;

    // Output operations signals
    wire [7:0]  s_result_exponent;
    reg         s_result_sign;
    wire        s_result_sign_sin;
    wire        s_result_sign_cos;
    wire        s_result_sign_rsqrt;
    wire        s_result_sign_log2;
    wire        s_result_sign_exp2;
    wire        s_result_sign_rcp;
    wire        s_result_sign_sqrt;
    wire [22:0] s_result_mantiza;
    wire [31:0] s_result_complete;


    // Constants
    // Fixed point representation of pi/2
    wire [23:0] C_HALF_PI = 24'hC90FDB;

    // -------------------------------------------------------------------------
    // Input data split
    // -------------------------------------------------------------------------
    assign s_in_sign     = src1_i[31];
    assign s_in_exponent = src1_i[30:23];
    assign s_in_mantiza  = src1_i[22:0];

    assign s_in_sin_cos_quad = s_in_exponent[7:6];

    // When input angle for sin or cos operation be greater than 1 a correction 
    // must be implemented in order to warranty that the input angle to the 
    // interpolater is always between input [0,1)
    assign s_half_pi_minus_x = C_HALF_PI - {1'b0, src1_i[23:0]};
    
    assign s_in_sin_cos_adj = (src1_i[23]) ? {1'b0, 7'b0000000, s_half_pi_minus_x} : src1_i;
    
    assign s_in_data_inter   = (selop_i[2:1] == 2'b00) ? s_in_sin_cos_adj : src1_i;
    
    // Adjust operation select for sin/cos based on quadrant
    assign s_in_oper_select = (selop_i[2:1] == 2'b00) ? 
                              {2'b00, (s_in_sin_cos_quad[0] ^ selop_i[0] ^ src1_i[23])} : 
                              selop_i;

    // -------------------------------------------------------------------------
    // Quadratic Interpolator component
    // -------------------------------------------------------------------------
    Quadratic_Interpolator uQuadraticInterpol (
        .src1_i          (s_in_data_inter),
        .selop_i         (s_in_oper_select),
        .Res_Quad_int_o  (s_Res_Quad_int_o)
    );

    // -------------------------------------------------------------------------
    // Log2(x) adjust add the exponent as integer part and table selection
    // -------------------------------------------------------------------------
    assign s_log2_Exp_eq_zero = (s_in_exponent == 8'd127);

    // Multiplication: Result_Quad(42 bits) * (0 & Mantisa & 18 zeros)
    // Adjusting widths for multiplication
    assign s_log2_mult_Mx = (s_Res_Quad_int_o[41:0] * {1'b0, s_in_mantiza, 18'b0});

    assign s_log2_sign     = (s_in_exponent < 8'd127);
    assign s_log2_sign_neg = ~s_log2_sign;

    assign s_log2_exp_sign_ext  = {7{s_log2_sign}};
    assign s_log2_fix_sign_ext  = {49{s_log2_sign}};
    
    // XOR operation equivalent
    assign s_log2_int_part_xor  = s_in_exponent[6:0] ^ s_log2_exp_sign_ext;
    assign s_log2_Fix_point_xor = {7'b0000000, s_Res_Quad_int_o[41:0]} ^ s_log2_fix_sign_ext;

    // Integer part logic
    assign s_log2_int_part = (s_log2_sign_neg) ? 
                             (8'b0 + s_log2_int_part_xor + 8'b1) : 
                             {1'b0, s_log2_int_part_xor};

    // Fix point combination
    assign s_log2_Fix_point_t = ({1'b0, s_log2_int_part[6:0], 32'b0} + s_log2_Fix_point_xor);
    assign s_log2_Fix_point   = (s_log2_sign) ? (s_log2_Fix_point_t + 49'b1) : s_log2_Fix_point_t;

    // Mux for log2 result based on exponent zero condition
    assign s_log2_res_unorm = (s_log2_Exp_eq_zero) ? 
                              {7'b0000000, s_log2_mult_Mx[82:41]} : 
                              {1'b0, s_log2_Fix_point[47:0]};

    // -------------------------------------------------------------------------
    // Normalization of interpolation result
    // -------------------------------------------------------------------------
    assign s_in_norm = (selop_i == 3'b011) ? 
                       {s_log2_res_unorm, 15'b0} : 
                       {7'b0000000, s_Res_Quad_int_o[41:0], 15'b0};

    CLZ uCountLeadingZeros (
        .i_data      (s_in_norm),
        .o_zeros     (s_num_of_Zeros),
        .o_MSB_zeros (s_MSB_zeros)
    );

    // Shift Left Logical based on zero count
    assign s_res_norm = s_in_norm << s_num_of_Zeros;

    // Rounding to nearest even
    assign s_rounding_even      = (s_res_norm[24] & s_res_norm[23]) | (s_res_norm[25] & s_res_norm[24]);
    assign s_mantiza_rounding   = {24'b0, s_rounding_even};
    assign s_rounding_mantiza   = {1'b0, s_res_norm[48:25]} + s_mantiza_rounding;
    
    assign s_rounding_exp       = {8'b0, s_rounding_mantiza[24]};
    // 9'sd7 - resize(unsigned(num_zeros), 9)
    assign s_exp_norm           = (9'sd7 - {3'b0, s_num_of_Zeros}) + s_rounding_exp;
    assign s_res_mantiza        = s_rounding_mantiza[22:0];

    // -------------------------------------------------------------------------
    // Exponent correction according to input equation
    // -------------------------------------------------------------------------
    // s_denorm_exp_Ex <= std_logic_vector(signed('0'&s_in_exponent)-127);
    assign s_denorm_exp_Ex = {1'b0, s_in_exponent} - 9'd127;

    assign s_Ex_1      = s_denorm_exp_Ex - 9'd1;
    // Arithmetic Shift Right (division by 2)
    assign s_Ex_1_srl  = {s_Ex_1[8], s_Ex_1[8:1]}; 
    assign s_Ex_srl    = {s_denorm_exp_Ex[8], s_denorm_exp_Ex[8:1]};

    assign s_rsqrt_Ex_1_srl_t = $signed(s_exp_norm) - $signed(s_Ex_1_srl);
    assign s_rsqrt_Ex_srl_t   = $signed(s_exp_norm) - $signed(s_Ex_srl);
    assign s_rcp_Exp_t        = $signed(s_exp_norm) - $signed(s_denorm_exp_Ex);

    assign s_log2_final_exp   = s_exp_norm;
    assign s_sin_final_exp   = s_exp_norm;
    assign s_cos_final_exp   = s_exp_norm;
    assign s_exp2_final_exp  = {{1'b0, s_in_exponent}}; // resize
    assign s_rcp_final_exp    = s_rcp_Exp_t;
    // Sqrt exponent: (Ex-1)/2 if odd, Ex/2 if even
    assign s_sqrt_final_exp   = (s_denorm_exp_Ex[0]) ? s_Ex_1_srl : s_Ex_srl;
    // Rsqrt exponent logic
    assign s_rsqrt_final_exp  = (s_denorm_exp_Ex[0]) ? s_rsqrt_Ex_1_srl_t : s_rsqrt_Ex_srl_t;

    // Mux for final exponent selection
    always @(*) begin
        case (selop_i)
            3'b000: s_final_exp_mux = s_sin_final_exp;
            3'b001: s_final_exp_mux = s_cos_final_exp;
            3'b010: s_final_exp_mux = s_rsqrt_final_exp;
            3'b011: s_final_exp_mux = s_log2_final_exp;
            3'b100: s_final_exp_mux = s_exp2_final_exp;
            3'b101: s_final_exp_mux = s_rcp_final_exp;
            3'b110: s_final_exp_mux = s_sqrt_final_exp;
            default: s_final_exp_mux = s_denorm_exp_Ex;
        endcase
    end

    // Final exponent bias correction and underflow check
    assign s_final_exp_t = ($signed(s_final_exp_mux) < -9'sd126 || s_MSB_zeros) ? 
                           9'b0 : 
                           ($signed(s_final_exp_mux) + 9'd127);

    // -------------------------------------------------------------------------
    // Output selection results
    // -------------------------------------------------------------------------
    assign s_result_sign_sin   = s_in_sign ^ s_in_sin_cos_quad[1];
    assign s_result_sign_cos   = s_in_sin_cos_quad[1] ^ s_in_sin_cos_quad[0];
    assign s_result_sign_log2  = s_log2_sign;
    assign s_result_sign_rcp   = s_in_sign;
    assign s_result_sign_exp2  = 1'b0;
    assign s_result_sign_rsqrt = 1'b0;
    assign s_result_sign_sqrt  = 1'b0;

    assign s_result_exponent   = s_final_exp_t[7:0];

    always @(*) begin
        case (selop_i)
            3'b000: s_result_sign = s_result_sign_sin;
            3'b001: s_result_sign = s_result_sign_cos;
            3'b010: s_result_sign = s_result_sign_rsqrt;
            3'b011: s_result_sign = s_result_sign_log2;
            3'b100: s_result_sign = s_result_sign_exp2;
            3'b101: s_result_sign = s_result_sign_rcp;
            3'b110: s_result_sign = s_result_sign_sqrt;
            default: s_result_sign = src1_i[31];
        endcase
    end

    assign s_result_mantiza = ($signed(s_final_exp_mux) < -9'sd126 || s_MSB_zeros) ? 
                              23'b0 : 
                              s_res_mantiza;

    assign s_result_complete = {s_result_sign, s_result_exponent, s_result_mantiza};

    SFU_Exceptions uExceptions (
        .i_data_input    (s_in_data_inter),
        .i_data_sin_cos  (src1_i),
        .i_oper_result   (s_result_complete),
        .i_selop         (s_in_oper_select),
        .o_result_solved (Result_o)
    );

endmodule
