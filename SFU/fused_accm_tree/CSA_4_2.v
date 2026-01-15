module CSA_4_2 (
    input  wire ci,  // 进位输入
    input  wire X1,  // 输入位 1
    input  wire X2,  // 输入位 2
    input  wire X3,  // 输入位 3
    input  wire X4,  // 输入位 4
    output wire co,  // 进位输出
    output wire C,   // 进位位输出
    output wire S    // 和位输出
);

    // 内部信号
    wire sxor1;
    wire sxor2;
    wire sxor3;

    // 计算异或中间信号
    assign sxor1 = X1 ^ X2;
    assign sxor2 = X3 ^ X4;
    assign sxor3 = sxor1 ^ sxor2;

    // 和位输出
    assign S = sxor3 ^ ci;

    // 进位输出
    assign co = (X3 & X4) | (X2 & X4) | (X2 & X3);

    // 进位位输出
    assign C = sxor3 ? ci : X1;

endmodule