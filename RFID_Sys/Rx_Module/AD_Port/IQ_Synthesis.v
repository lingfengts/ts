/***************************
File 		: IQ_Synthesis.v
Project 	: RFID
Author 		: zhangqi
Time 		: 20170413
Function 	: IQ数据合成。	
modify by zhouhang 20170511
v1.1.0511
v1.2.0514 增加抽样模块、带通滤波器和插值滤波器
***************************/
module 	IQ_Synthesis(
		clk_i,
		rst_n,
		
		de_mode_i,
		set_speed_i,
		set_trext_i,
		sample_enable_i,
		rx_enable_i,
		
		i_data_in,
		q_data_in,
		
		i_data_o,
		q_data_o,
		
		sig_detect_o
		);


input wire					clk_i;
input wire 					rst_n;

input wire [1:0] de_mode_i;
input wire [2:0] set_speed_i;
input wire set_trext_i;
input wire sample_enable_i;
input wire rx_enable_i;

input wire signed [11:0] 	i_data_in;
input wire signed [11:0] 	q_data_in;

output wire signed [11:0] 	i_data_o;
output wire signed [11:0] 	q_data_o;

output wire sig_detect_o;
/*********************************************/
wire signed [22:0] i_mult_data;  //I路自乘输出
wire signed [22:0] q_mult_data;  //Q路自乘输出
wire signed [23:0] iq_data_plus;

wire [11:0] iq_data_sort;  	//平方根后输出
wire [11:0] iq_data_fix;		//修正超范围的数
wire signed [12:0] iq_data_remain;  //平方根后余数
wire signed [11:0] iq_synthesis_data;  //IQ合成后的数据
wire signed [11:0] i_synthesis_data;
wire signed [11:0] q_synthesis_data;

wire iq_data_lock;
wire set_lock;  //数据锁定选择

//延时
reg [1:0] delay_i_sign;
reg [1:0] delay_q_sign;

always@(posedge clk_i,negedge rst_n)
	begin
	if(!rst_n)
		begin
		delay_i_sign <= 2'd0;
		delay_q_sign <= 2'd0;
		end
	else
		begin
		delay_i_sign <= {delay_i_sign[0],i_data_in[11]};
		delay_q_sign <= {delay_q_sign[0],q_data_in[11]};
		end
	end

wire [15:0] iq_data_amp;
wire [11:0] qdata_o;
	
//assign iq_data_lock = set_lock ? delay_i_sign[1] : delay_q_sign[1];
assign iq_data_lock = delay_q_sign[1];

assign iq_data_amp = {iq_data_sort,4'd0};

assign iq_data_fix = (iq_data_amp > 12'd2047) ? 12'd2047 : iq_data_amp;

assign iq_synthesis_data = iq_data_lock ? ((~iq_data_fix) + 12'd1) : iq_data_fix;

assign iq_data_plus = i_mult_data + q_mult_data;

assign i_synthesis_data = delay_i_sign[1] ? ((~iq_data_sort) + 1'b1) : iq_data_sort;
assign q_synthesis_data = delay_q_sign[1] ? ((~iq_data_sort) + 1'b1) : iq_data_sort;

//自乘 I路
Arithmetic_Mult		I_Arithmetic_Mult(
					.clk_i(clk_i),
					.rst_n_i(rst_n),
					
					.valid_i(1'b1),
					.dataa_i(i_data_in),
					.datab_i(i_data_in),
					
					.data_o(i_mult_data)
					);
defparam I_Arithmetic_Mult.SET_DATAA_WIDTH = 12;
defparam I_Arithmetic_Mult.SET_DATAB_WIDTH = 12;



//自乘 Q路
Arithmetic_Mult		Q_Arithmetic_Mult(
					.clk_i(clk_i),
					.rst_n_i(rst_n),
					
					.valid_i(1'b1),
					.dataa_i(q_data_in),
					.datab_i(q_data_in),
					
					.data_o(q_mult_data)
					);
defparam Q_Arithmetic_Mult.SET_DATAA_WIDTH = 12;
defparam Q_Arithmetic_Mult.SET_DATAB_WIDTH = 12;


//平方根
Sort				Sort_inst (
					.aclr (~rst_n),  //高电平复位
					.clk ( clk_i ),
					.radical ( iq_data_plus ),
					.q ( iq_data_sort ),
					.remainder ( iq_data_remain )
					);

//功率检测
IQ_Power M_IQ_Power(
	.clk_i(clk_i),
	.rst_n_i(rst_n),
	
	.sample_enable_i(sample_enable_i),
	.rx_enable_i(rx_enable_i),
	.de_mode_i(de_mode_i),
	.set_speed_i(set_speed_i),
	.set_trext_i(set_trext_i),
	
	.i_mult_i(i_mult_data),
	.q_mult_i(q_mult_data),
	
	.sig_detect_o(sig_detect_o)
);

filter_fir		i_filter_fir(
					.clk_i(clk_i),
					.rst_n(rst_n),
					.BLF_SPEED(),
					.data_i(i_synthesis_data),
					 
					.filter_o(i_data_o)  //qdata_o
					);	
					
					
filter_fir		q_filter_fir(
					.clk_i(clk_i),
					.rst_n(rst_n),
					.BLF_SPEED(),
					.data_i(q_synthesis_data),
					 
					.filter_o(q_data_o)  //qdata_o
					);
					
endmodule
