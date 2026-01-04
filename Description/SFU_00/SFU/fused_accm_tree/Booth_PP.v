module Booth_PP #(
    parameter DATA_WIDTH = 8
)(
    input  wire x_i0,                // Booth 编码位 0
    input  wire x_i1,                // Booth 编码位 1
    input  wire x_i2,                // Booth 编码位 2
    input  wire [DATA_WIDTH-1:0] Data_i,  // 输入数据
    output reg  [DATA_WIDTH-1:0] Data_o,  // 输出部分积
    output reg  adj_o                // 调整信号输出
);

    // 内部信号
    wire signo_booth;
    wire two_m;
    wire zero;
    wire signo_oper;
    wire [DATA_WIDTH-1:0] shift;
    wire [DATA_WIDTH-1:0] sign_extend;
    wire [DATA_WIDTH-1:0] data_comp;
    wire [DATA_WIDTH-1:0] zero_extend;
    wire [DATA_WIDTH-1:0] data_o_tmp;

    // 计算 Booth 符号位
    assign signo_booth = (x_i2 & (~x_i1)) | (x_i2 & (~x_i0));

    // 计算是否需要乘以 2 或 -2
    assign two_m = (x_i2 & (~x_i1) & (~x_i0)) | ((~x_i2) & x_i1 & x_i0);

    // 计算是否为零（无需生成部分积）
    assign zero = (x_i2 | x_i1 | x_i0) & ((~x_i2) | (~x_i1) | (~x_i0));

    // 计算操作数的符号位
    assign signo_oper = signo_booth ^ Data_i[DATA_WIDTH-1];

    // 根据 Booth 编码移位（乘以 1 或 2）
    assign shift = two_m ? {Data_i[DATA_WIDTH-2:0], 1'b0} : {1'b0, Data_i[DATA_WIDTH-2:0]};

    // 符号扩展
    assign sign_extend = {DATA_WIDTH{signo_oper}};

    // 计算补码（异或操作）
    assign data_comp = sign_extend ^ shift;

    // 零扩展（用于清零部分积）
    assign zero_extend = {DATA_WIDTH{zero}};

    // 清零部分积（当 zero=1 时）
    assign data_o_tmp = zero_extend & data_comp;

    // 组合逻辑输出
    always @(*) begin
        // 最高位取反
        Data_o[DATA_WIDTH-1] = ~data_o_tmp[DATA_WIDTH-1];
        // 其余位直接输出
        Data_o[DATA_WIDTH-2:0] = data_o_tmp[DATA_WIDTH-2:0];
        // 调整信号
        adj_o = signo_oper & zero;
    end

endmodule