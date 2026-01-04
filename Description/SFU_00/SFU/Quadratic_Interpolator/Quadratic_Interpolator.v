// Proyecto				: 	SFU IEEE754
// Nombre de archivo	: 	Quadratic_Interpolator.vhd
// Titulo				: 	Quadratic_Interpolator
//---------------------------------------------------------------------------
// Descripcion			: 	This unit performs the Quadratic aproximation follow the methox exposed by oberman
//						  		the function performs the operation F=C2*X2^2 + C1X2 + C0 where C0, C1 and C2 are
//                      constants obtainded from mimimax aproximation algorithm, X2 is the 17 or 16 LSB of mantiza
//						  		Result is a 43 bit data using the representation SM.FFFFFFFFFFFF
// 							This componet performs Quadratic interpolation for sin(x), cos(x), rsqrt(x), log2(x), exp2(x), 1/x, and sqrt(x)
// 							operations the input is a 32 bit IEEE754 number representation and de output is a 43 bit Sign magnitud in
// 							fixed point representation using the format SM.FFFFFFFFFFF 1 bit signm 1 bit integer partm and 41 bits fractional
// 							this componet computes the funtions only using the mantiza or significand: sin(x)/cos(x) only in range [0,1)
// 							rsqrt(x), log2(x), 1/x, and sqrt(x) in range (1,2) nd exp2(x) in range (0,1).
//---------------------------------------------------------------------------
// Universidad Pedagogica y Tecnologica de Colombia.
// Facultad de ingenieria.
// Escuela de ingenieria Electronica - extension Tunja.
//
// Autor: Juan David Guerrero Balaguera; Edwar Javier Patiño
// October 2020
//---------------------------------------------------------------------------

module Quadratic_Interpolator(
        input wire [31:0] src1_i,
        input wire [2:0] selop_i,
        output wire [42:0] Res_Quad_int_o
    );

    //IEE754 input data
    //operation selection
    //IEE754 result data output



    wire [28:0] s_C0 = 1'b0;
    wire [19:0] s_C1 = 1'b0;
    wire [13:0] s_C2 = 1'b0;
    wire [33:0] s_X2X2 = 1'b0;
    wire [15:0] s_X2X2_approx = 1'b0;
    wire [16:0] s_X2 = 1'b0;
    wire [6:0] s_X1 = 1'b0;
    wire s_m6 = 1'b0;
    wire s_Exp_Zero = 1'b0;
    wire s_Exp_even = 1'b0;
    wire [22:0] s_in_mantiza;
    wire [7:0] s_in_exponent;
    wire s_in_sign = 1'b0;
    reg [3:0] s_coeff_select = 1'b0;
    wire [4:0] s_Operation = 1'b0;

    assign s_in_sign = src1_i[31];
    assign s_in_exponent = src1_i[30:23];
    assign s_in_mantiza = src1_i[22:0];
    assign s_m6 = (( ~selop_i[1]) & ( ~selop_i[0])) | ( ~(selop_i[2] ^ selop_i[1])) | (s_Exp_Zero & ( ~selop_i[2]) & selop_i[0]);
    //It determines wich operations use m=6 bits
    assign s_X2[16] = s_m6 & s_in_mantiza[16];
    assign s_X2[15:0] = s_in_mantiza[15:0];
    assign s_X1 = s_in_mantiza[22:16];
    // When m=6 you must take form X1(22 downto 17) when m=7 you can take X1 complete
    assign s_Exp_Zero = (s_in_exponent) == 127 ? 1'b1 : 1'b0;
    // This bit inform when the input exponent is zero
    assign s_Exp_even = s_in_exponent[0];
    // This bit informs when Exponent is even=1 odd=0
    assign s_Operation = {selop_i,s_Exp_Zero,s_Exp_even};
    always @(*) begin
        case(s_Operation)
            5'b00000,5'b00001,5'b00010,5'b00011 : s_coeff_select <= 4'b0000;
            // sin
            5'b00100,5'b00101,5'b00110,5'b00111 : s_coeff_select <= 4'b0001;
            // cos
            5'b01001,5'b01011 : s_coeff_select <= 4'b0010;
            // rsqrt when exp is even
            5'b01000,5'b01010 : s_coeff_select <= 4'b0011;
            // rsqrt when exp is odd
            5'b01100,5'b01101 : s_coeff_select <= 4'b0100;
            // log2 when exp != 0
            5'b01110,5'b01111 : s_coeff_select <= 4'b0101;
            // log2 when exp = 0 (correct this when the correct table be available with 7)
            5'b10000,5'b10001,5'b10010,5'b10011 : s_coeff_select <= 4'b0110;
            // exp 2
            5'b10100,5'b10101,5'b10110,5'b10111 : s_coeff_select <= 4'b0111;
            // 1/x operation
            5'b11001,5'b11011 : s_coeff_select <= 4'b1000;
            // sqrt when exp is even
            5'b11000,5'b11010 : s_coeff_select <= 4'b1001;
            // sqrt when exp is odd
            default : s_coeff_select <= 4'b1111;
        endcase
    end

    //=========================================== Coefficients Tables ==============================================================================
    // Here the Coeffients Tables must be instantiated
    // the followign lines must be conected to the component when it be intantiated
    //=============================================================================================================================================
    ROM uLookUpTable(
            .addr(s_X1),
            .fn(s_coeff_select),
            .C0(s_C0),
            .C1(s_C1),
            .C2(s_C2));

    // ==========================================Special Square Unit ==============================================================================
    // Here must be the special square unit Edwar Patiño
    // ============================================================================================================================================
    squaring u_SpecialSquaringUnit(
                 .d_in(s_X2),
                 .d_out(s_X2X2));

    assign s_X2X2_approx = {1'b0,s_X2X2[33:19]};
    //=========================================== Fused Accumulation Tree =========================================================================
    // This componetn performs the operation F=C2*X2^2 + C1X2 + C0 using booth coding to get partial producto and fussed accumulation tree
    // to get the final result using 43 bits.
    //=============================================================================================================================================
    fused_accum_tree uFusedAccTree(
                         .C0(s_C0),
                         .C1(s_C1),
                         .C2(s_C2),
                         .X2X2(s_X2X2_approx),
                         .X2(s_X2),
                         .Result(Res_Quad_int_o));


endmodule
