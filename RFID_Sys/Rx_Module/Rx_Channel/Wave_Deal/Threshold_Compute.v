//created by zhouhang 20170211
//阈值跟踪计算 高度阈值取1/2 宽度阈值取1/4 三角比例方法
//new_high = 3*old_high/4 + high_max/2/4 老阈值权重较高
//new_width = width * new_high / (high_max - old_high) / 4
//v1.0.0211

module Threshold_Compute(
	start_i,
	
	width_i,
	high_max_i,
	
	old_th_width_i,
	old_th_high_i,
	
	new_th_width_o,
	new_th_high_o
);
parameter SET_HIGH_DIV = 1;
parameter SET_WIDTH_DIV = 2;
parameter SET_P_OLD = 3;
parameter SET_P_DIV = 2;

input wire start_i;
input wire [7:0] width_i;
input wire signed [15:0] high_max_i;
input wire [7:0] old_th_width_i;
input wire signed [15:0] old_th_high_i;
output wire [7:0] new_th_width_o;
output wire signed [15:0] new_th_high_o;

wire signed [15:0] th_high_old;
wire signed [15:0] th_high_expect;
assign th_high_old = (SET_P_OLD * old_th_high_i) >>> SET_P_DIV;
assign th_high_expect = high_max_i >>> (SET_HIGH_DIV + SET_P_DIV);
assign new_th_high_o = th_high_old + th_high_expect;

wire [23:0] th_width_expect;
wire [15:0] high_old;
wire [15:0] high_new;

assign high_old = high_max_i - old_th_high_i;
assign high_new = high_max_i - new_th_high_o;

wire [23:0] ret_mult;
wire [23:0] ret_div;
TC_Mult M_TC_Mult(
	.dataa	(high_new),
	.datab	(old_th_width_i),
	.result	(ret_mult)
	);

TC_Div M_TC_Div(
	.denom		(high_old),
	.numer		(ret_mult),
	.quotient	(ret_div),
	.remain		()
	);

assign th_width_expect = (ret_div >> SET_WIDTH_DIV);
assign new_th_width_o = (th_width_expect > 24'd250) ? 8'd200 : th_width_expect[7:0];
 
endmodule
 