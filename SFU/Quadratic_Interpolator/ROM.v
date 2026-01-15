module ROM #(
    parameter integer bus_C0 = 29,
    parameter integer bus_C1 = 20,
    parameter integer bus_C2 = 14,
    parameter integer fn_bits = 4,
    parameter integer add_bits = 7
)(
    input  wire [add_bits-1:0] addr,
    input  wire [fn_bits-1:0]  fn,
    output reg  [bus_C0-1:0]   C0,
    output reg  [bus_C1-1:0]   C1,
    output reg  [bus_C2-1:0]   C2
);

wire [bus_C0-1:0] romC0_0;
wire [bus_C0-1:0] romC0_1;
wire [bus_C0-1:0] romC0_2;
wire [bus_C0-1:0] romC0_3;
wire [bus_C0-1:0] romC0_4;
wire [bus_C0-1:0] romC0_5;
wire [bus_C0-1:0] romC0_6;
wire [bus_C0-1:0] romC0_7;
wire [bus_C0-1:0] romC0_8;
wire [bus_C0-1:0] romC0_9;

wire [bus_C1-1:0] romC1_0;
wire [bus_C1-1:0] romC1_1;
wire [bus_C1-1:0] romC1_2;
wire [bus_C1-1:0] romC1_3;
wire [bus_C1-1:0] romC1_4;
wire [bus_C1-1:0] romC1_5;
wire [bus_C1-1:0] romC1_6;
wire [bus_C1-1:0] romC1_7;
wire [bus_C1-1:0] romC1_8;
wire [bus_C1-1:0] romC1_9;

wire [bus_C2-1:0] romC2_0;
wire [bus_C2-1:0] romC2_1;
wire [bus_C2-1:0] romC2_2;
wire [bus_C2-1:0] romC2_3;
wire [bus_C2-1:0] romC2_4;
wire [bus_C2-1:0] romC2_5;
wire [bus_C2-1:0] romC2_6;
wire [bus_C2-1:0] romC2_7;
wire [bus_C2-1:0] romC2_8;
wire [bus_C2-1:0] romC2_9;

LUT_C0_sin u_C0_sin (
    .addr(addr[add_bits-1:1]),
    .data(romC0_0)
);

LUT_C0_cos u_C0_cos (
    .addr(addr[add_bits-1:1]),
    .data(romC0_1)
);

LUT_C0_reci_sqrt_1_2 u_C0_reci_sqrt_1_2 (
    .addr(addr),
    .data(romC0_2)
);

LUT_C0_reci_sqrt_2_4 u_C0_reci_sqrt_2_4 (
    .addr(addr),
    .data(romC0_3)
);

LUT_C0_ln2 u_C0_ln2 (
    .addr(addr),
    .data(romC0_4)
);

LUT_C0_ln2e0 u_C0_ln2e0 (
    .addr(addr[add_bits-1:1]),
    .data(romC0_5)
);

LUT_C0_exp u_C0_exp (
    .addr(addr[add_bits-1:1]),
    .data(romC0_6)
);

LUT_C0_reci u_C0_reci (
    .addr(addr),
    .data(romC0_7)
);

LUT_C0_sqrt_1_2 u_C0_sqrt_1_2 (
    .addr(addr[add_bits-1:1]),
    .data(romC0_8)
);

LUT_C0_sqrt_2_4 u_C0_sqrt_2_4 (
    .addr(addr[add_bits-1:1]),
    .data(romC0_9)
);

always @* begin
    case (fn)
        0: C0 = romC0_0;
        1: C0 = romC0_1;
        2: C0 = romC0_2;
        3: C0 = romC0_3;
        4: C0 = romC0_4;
        5: C0 = romC0_5;
        6: C0 = romC0_6;
        7: C0 = romC0_7;
        8: C0 = romC0_8;
        9: C0 = romC0_9;
        default: C0 = {bus_C0{1'b0}};
    endcase
end

LUT_C1_sin u_C1_sin (
    .addr(addr[add_bits-1:1]),
    .data(romC1_0)
);

LUT_C1_cos u_C1_cos (
    .addr(addr[add_bits-1:1]),
    .data(romC1_1)
);

LUT_C1_reci_sqrt_1_2 u_C1_reci_sqrt_1_2 (
    .addr(addr),
    .data(romC1_2)
);

LUT_C1_reci_sqrt_2_4 u_C1_reci_sqrt_2_4 (
    .addr(addr),
    .data(romC1_3)
);

LUT_C1_ln2 u_C1_ln2 (
    .addr(addr),
    .data(romC1_4)
);

LUT_C1_ln2e0 u_C1_ln2e0 (
    .addr(addr[add_bits-1:1]),
    .data(romC1_5)
);

LUT_C1_exp u_C1_exp (
    .addr(addr[add_bits-1:1]),
    .data(romC1_6)
);

LUT_C1_reci u_C1_reci (
    .addr(addr),
    .data(romC1_7)
);

LUT_C1_sqrt_1_2 u_C1_sqrt_1_2 (
    .addr(addr[add_bits-1:1]),
    .data(romC1_8)
);

LUT_C1_sqrt_2_4 u_C1_sqrt_2_4 (
    .addr(addr[add_bits-1:1]),
    .data(romC1_9)
);

always @* begin
    case (fn)
        0: C1 = romC1_0;
        1: C1 = romC1_1;
        2: C1 = romC1_2;
        3: C1 = romC1_3;
        4: C1 = romC1_4;
        5: C1 = romC1_5;
        6: C1 = romC1_6;
        7: C1 = romC1_7;
        8: C1 = romC1_8;
        9: C1 = romC1_9;
        default: C1 = {bus_C1{1'b0}};
    endcase
end

LUT_C2_sin u_C2_sin (
    .addr(addr[add_bits-1:1]),
    .data(romC2_0)
);

LUT_C2_cos u_C2_cos (
    .addr(addr[add_bits-1:1]),
    .data(romC2_1)
);

LUT_C2_reci_sqrt_1_2 u_C2_reci_sqrt_1_2 (
    .addr(addr),
    .data(romC2_2)
);

LUT_C2_reci_sqrt_2_4 u_C2_reci_sqrt_2_4 (
    .addr(addr),
    .data(romC2_3)
);

LUT_C2_ln2 u_C2_ln2 (
    .addr(addr),
    .data(romC2_4)
);

LUT_C2_ln2e0 u_C2_ln2e0 (
    .addr(addr[add_bits-1:1]),
    .data(romC2_5)
);

LUT_C2_exp u_C2_exp (
    .addr(addr[add_bits-1:1]),
    .data(romC2_6)
);

LUT_C2_reci u_C2_reci (
    .addr(addr),
    .data(romC2_7)
);

LUT_C2_sqrt_1_2 u_C2_sqrt_1_2 (
    .addr(addr[add_bits-1:1]),
    .data(romC2_8)
);

LUT_C2_sqrt_2_4 u_C2_sqrt_2_4 (
    .addr(addr[add_bits-1:1]),
    .data(romC2_9)
);

always @* begin
    case (fn)
        0: C2 = romC2_0;
        1: C2 = romC2_1;
        2: C2 = romC2_2;
        3: C2 = romC2_3;
        4: C2 = romC2_4;
        5: C2 = romC2_5;
        6: C2 = romC2_6;
        7: C2 = romC2_7;
        8: C2 = romC2_8;
        9: C2 = romC2_9;
        default: C2 = {bus_C2{1'b0}};
    endcase
end

endmodule
