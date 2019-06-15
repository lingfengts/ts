//created by zhouhang 20170405
//filter 255阶FIR滤波器

module BandPass_Filter(
	clk_i,
	rst_n_i,
	
	set_speed_i,
	
	valid_i,
	data_i,
	valid_o,
	data_o
);
parameter SET_DATA_WIDTH = 12;
parameter SET_OUT_WIDTH = 12;
parameter SET_ORDER = 256;
parameter SET_AMP_LG = 9;

parameter TRUE_ORDER = SET_ORDER >> 1;		//实际参与计算的阶数

input wire clk_i;
input wire rst_n_i;

input wire [2:0] set_speed_i;

input wire valid_i;
input wire signed [SET_DATA_WIDTH-1:0] data_i;

output wire valid_o;
output reg signed [SET_OUT_WIDTH-1:0] data_o;

wire [9:0] rom_addr;
reg [7:0] param_addr = 8'd0;	//for sim initial
wire signed [8:0] rom_q;

assign rom_addr = {set_speed_i,param_addr[6:0]};
BandPass_Filter_Rom M_BandPass_Filter_Rom(
	.address(rom_addr),
	.clock(clk_i),
	.q(rom_q)
	);
	
//valid时序
reg flag_init_finish = 1'b0; //for sim initial
wire cache_valid;
reg [5:0] delay_valid;
wire valid_l0;
wire valid_l1;
wire valid_l2;
wire valid_l3;
wire valid_l4;

assign cache_valid = flag_init_finish & valid_i;//初始化未完成valid无效
always@(posedge clk_i,negedge rst_n_i)
	begin
	if(!rst_n_i)
		begin
		delay_valid <= 6'd0;
		end
	else
		begin
		delay_valid <= {delay_valid[4:0],cache_valid};
		end
	end
assign valid_l0 = delay_valid[0];
assign valid_l1 = delay_valid[1];
assign valid_l2 = delay_valid[2];
assign valid_l3 = delay_valid[3];
assign valid_l4 = delay_valid[4];
assign valid_o = delay_valid[5];

//滤波器参数初始化,参数不响应复位
reg [2:0] delay_speed = 3'd0;//for sim initial
wire flag_update_param;

always@(posedge clk_i)
	begin
	delay_speed <= set_speed_i;
	end
assign flag_update_param = (delay_speed != set_speed_i);

//地址控制
always@(posedge clk_i)
	begin
	if(flag_update_param)
		begin
		param_addr <= 8'd0;
		flag_init_finish <= 1'b0;
		end
	else
		begin
		if(param_addr < (TRUE_ORDER + 1))
			begin
			param_addr <= param_addr + 8'd1;
			end
		else
			begin
			flag_init_finish <= 1'b1;
			end
		end
	end
//参数更新
reg signed [8:0] lpf_param [0:TRUE_ORDER-1];
genvar param_ix;
generate
for(param_ix = 1; param_ix <= TRUE_ORDER; param_ix = param_ix + 1)
	begin:BLOCK_PARAM
	//更新参数
	always@(posedge clk_i)
		begin
		if(param_addr == (param_ix))
			begin
			lpf_param[param_ix-1] <= rom_q;
			end
		end	
	end
endgenerate

//乘数缓存
reg signed [SET_DATA_WIDTH-1:0] cache_mult [0:SET_ORDER-1];
always@(posedge clk_i,negedge rst_n_i)
	begin
	if(!rst_n_i)
		begin
		cache_mult[0] <= {SET_DATA_WIDTH{1'b0}};
		end
	else
		begin
		if(cache_valid)
			cache_mult[0] <= data_i;
		end
	end

genvar cache_ix;
generate
for(cache_ix = 1; cache_ix < SET_ORDER; cache_ix = cache_ix + 1)
	begin:BLOCK_CACHE
	always@(posedge clk_i,negedge rst_n_i)
		begin
		if(!rst_n_i)
			begin
			cache_mult[cache_ix] <= {SET_DATA_WIDTH{1'b0}};
			end
		else
			begin
			if(cache_valid)
				cache_mult[cache_ix] <= cache_mult[cache_ix - 1];
			end
		end
	end
endgenerate
	
//L0流水线,乘法	
parameter ADD_WIDTH_L0 = SET_DATA_WIDTH + 1;
parameter MULT_OUT_WIDTH = ADD_WIDTH_L0 + 9 - 1; 
reg signed [MULT_OUT_WIDTH-1:0] mult_out [0:TRUE_ORDER-1];

genvar ix_l0;
generate
for(ix_l0 = 0; ix_l0 < TRUE_ORDER; ix_l0 = ix_l0 + 1)
	begin:BLOCK_L0
	wire signed [ADD_WIDTH_L0-1:0] add_L0;
	wire signed [MULT_OUT_WIDTH-1:0] mult_ret;
	
	assign add_L0 = {cache_mult[ix_l0][SET_DATA_WIDTH-1],
							cache_mult[ix_l0]} + 
							{cache_mult[SET_ORDER - ix_l0 - 1][SET_DATA_WIDTH-1],
							cache_mult[SET_ORDER - ix_l0 - 1]};
	
	Arithmetic_Mult M_LPF_AM(
		.clk_i(clk_i),
		.rst_n_i(rst_n_i),
		
		.valid_i(valid_l0),
		.dataa_i(add_L0),
		.datab_i(lpf_param[ix_l0]),
		
		.data_o(mult_ret)
	);
	defparam M_LPF_AM.SET_DATAA_WIDTH = ADD_WIDTH_L0;
	defparam M_LPF_AM.SET_DATAB_WIDTH = 9;
	
	always@(mult_ret)
		begin
		mult_out[ix_l0] = mult_ret;
		end
		
	end
endgenerate

//L1流水线
parameter ADD_LG_L1 = 2;
parameter ADD_WIDTH_L1 = MULT_OUT_WIDTH + ADD_LG_L1;
parameter NUM_L1 = (TRUE_ORDER >> ADD_LG_L1);
reg signed [ADD_WIDTH_L1-1:0] cache_l1 [0:NUM_L1-1];

genvar ix_l1;
generate
for(ix_l1 = 0; ix_l1 < NUM_L1; ix_l1 = ix_l1 + 1)
	begin:BLOCK_L1
	wire signed [ADD_WIDTH_L1-1:0] add_L1;
	assign add_L1 =  {{ADD_LG_L1{mult_out[ix_l1*4+0][MULT_OUT_WIDTH-1]}},
							mult_out[ix_l1*4+0]} + 
							{{ADD_LG_L1{mult_out[ix_l1*4+1][MULT_OUT_WIDTH-1]}},
							mult_out[ix_l1*4+1]} + 
							{{ADD_LG_L1{mult_out[ix_l1*4+2][MULT_OUT_WIDTH-1]}},
							mult_out[ix_l1*4+2]} + 
							{{ADD_LG_L1{mult_out[ix_l1*4+3][MULT_OUT_WIDTH-1]}},
							mult_out[ix_l1*4+3]};
	
	always@(posedge clk_i,negedge rst_n_i)
		begin
		if(!rst_n_i)
			begin
			cache_l1[ix_l1] <= {ADD_WIDTH_L1{1'b0}};
			end
		else
			begin
			if(valid_l1)
				cache_l1[ix_l1] <= add_L1;
			end
		end
	end
endgenerate

//L2流水线
parameter ADD_LG_L2 = 2;
parameter ADD_WIDTH_L2 = ADD_WIDTH_L1 + ADD_LG_L2;
parameter NUM_L2 = (NUM_L1 >> ADD_LG_L2);
reg signed [ADD_WIDTH_L2-1:0] cache_l2 [0:NUM_L2-1];

genvar ix_l2;
generate
for(ix_l2 = 0; ix_l2 < NUM_L2; ix_l2 = ix_l2 + 1)
	begin:BLOCK_L2
	wire signed [ADD_WIDTH_L2-1:0] add_L2;
	assign add_L2 =  {{ADD_LG_L2{cache_l1[ix_l2*4+0][ADD_WIDTH_L1-1]}},
							cache_l1[ix_l2*4+0]} + 
							{{ADD_LG_L2{cache_l1[ix_l2*4+1][ADD_WIDTH_L1-1]}},
							cache_l1[ix_l2*4+1]} + 
							{{ADD_LG_L2{cache_l1[ix_l2*4+2][ADD_WIDTH_L1-1]}},
							cache_l1[ix_l2*4+2]} + 
							{{ADD_LG_L2{cache_l1[ix_l2*4+3][ADD_WIDTH_L1-1]}},
							cache_l1[ix_l2*4+3]};
	
	always@(posedge clk_i,negedge rst_n_i)
		begin
		if(!rst_n_i)
			begin
			cache_l2[ix_l2] <= {ADD_WIDTH_L2{1'b0}};
			end
		else
			begin
			if(valid_l2)
				cache_l2[ix_l2] <= add_L2;
			end
		end
	end
endgenerate

//L3流水线
parameter ADD_LG_L3 = 2;
parameter ADD_WIDTH_L3 = ADD_WIDTH_L2 + ADD_LG_L3;
parameter NUM_L3 = (NUM_L2 >> ADD_LG_L3);
reg signed [ADD_WIDTH_L3-1:0] cache_l3 [0:NUM_L3-1];

genvar ix_l3;
generate
for(ix_l3 = 0; ix_l3 < NUM_L3; ix_l3 = ix_l3 + 1)
	begin:BLOCK_L3
	wire signed [ADD_WIDTH_L3-1:0] add_L3;
	assign add_L3 =  {{ADD_LG_L3{cache_l2[ix_l3*4+0][ADD_WIDTH_L2-1]}},
							cache_l2[ix_l3*4+0]} + 
							{{ADD_LG_L3{cache_l2[ix_l3*4+1][ADD_WIDTH_L2-1]}},
							cache_l2[ix_l3*4+1]} + 
							{{ADD_LG_L3{cache_l2[ix_l3*4+2][ADD_WIDTH_L2-1]}},
							cache_l2[ix_l3*4+2]} + 
							{{ADD_LG_L3{cache_l2[ix_l3*4+3][ADD_WIDTH_L2-1]}},
							cache_l2[ix_l3*4+3]};
	
	always@(posedge clk_i,negedge rst_n_i)
		begin
		if(!rst_n_i)
			begin
			cache_l3[ix_l3] <= {ADD_WIDTH_L3{1'b0}};
			end
		else
			begin
			if(valid_l3)
				cache_l3[ix_l3] <= add_L3;
			end
		end
	end
endgenerate

//L4流水线
parameter ADD_LG_L4 = 1;
parameter ADD_WIDTH_L4 = ADD_WIDTH_L3 + ADD_LG_L4;
parameter NUM_L4 = (NUM_L3 >> ADD_LG_L4);
reg signed [ADD_WIDTH_L4-1:0] cache_l4 [0:NUM_L4-1];

genvar ix_l4;
generate
for(ix_l4 = 0; ix_l4 < NUM_L4; ix_l4 = ix_l4 + 1)
	begin:BLOCK_L4
	wire signed [ADD_WIDTH_L4-1:0] add_L4;
	assign add_L4 =  {{ADD_LG_L4{cache_l3[ix_l4*2+0][ADD_WIDTH_L3-1]}},
							cache_l3[ix_l4*2+0]} + 
							{{ADD_LG_L4{cache_l3[ix_l4*2+1][ADD_WIDTH_L3-1]}},
							cache_l3[ix_l4*2+1]};
	
	always@(posedge clk_i,negedge rst_n_i)
		begin
		if(!rst_n_i)
			begin
			cache_l4[ix_l4] <= {ADD_WIDTH_L4{1'b0}};
			end
		else
			begin
			if(valid_l4)
				cache_l4[ix_l4] <= add_L4;
			end
		end
	end
endgenerate

//输出
parameter SUM_WIDTH = ADD_WIDTH_L4 - SET_AMP_LG;
wire signed [SUM_WIDTH-1:0] data_sum;
wire signed [SUM_WIDTH-1:0] data_max;
wire signed [SUM_WIDTH-1:0] data_min;

assign data_sum = cache_l4[0][ADD_WIDTH_L4-1:SET_AMP_LG]; //去除参数放大倍数
assign data_max = 2047;
assign data_min = 0 - data_max;

always@(data_max,data_min,data_sum)
	begin
	if(data_sum > data_max)
		begin
		data_o = data_max[SET_OUT_WIDTH-1:0];
		end
	else if(data_sum < data_min)
		begin
		data_o = data_min[SET_OUT_WIDTH-1:0];
		end
	else
		begin
		data_o = data_sum[SET_OUT_WIDTH-1:0];
		end
	end

endmodule
