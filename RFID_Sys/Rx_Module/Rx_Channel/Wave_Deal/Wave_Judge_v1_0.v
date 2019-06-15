//created by zhouhang 20170208
//AD输入边沿判断
//v1.0.0208

module Wave_Judge(
	clk_i,
	rst_n_i,
	
	data_i,
	sub_data_i,
	
	rise_edge_o,
	fall_edge_o,
	gap_edge_o
);
parameter SET_DEF_MIN_HIGH = 16'd100;
parameter SET_WIDTH_MAX = 8'd250;
parameter SET_LOCK_ZONE = 8'd100;
parameter SET_LOCK_NOISE = 8'd3; //在锁定阶段 高于此值认为不是噪声
parameter SET_EDGE_WIDTH = 8'd100; //当判定的边沿宽度大于此值认为不是正常边沿
parameter SET_LOCK_HIGH_STEP = 16'd50;
parameter SET_LOCK_WIDTH_STEP = 8'd1;
parameter SET_RISE_WIDTH = 8'd4;
parameter SET_FALL_WIDTH = 8'd4;

input wire clk_i;
input wire rst_n_i;

input wire signed [15:0] data_i;
input wire signed [15:0] sub_data_i;

output reg rise_edge_o;
output reg fall_edge_o;
output reg [15:0] gap_edge_o;

reg flag_in_rise;
reg delay_in_rise;
wire pdg_in_rise;
wire ndg_in_rise;
reg flag_in_fall;
reg delay_in_fall;
wire ndg_in_fall;
wire pdg_in_fall;

reg flag_locked;
reg delay_locked;
wire pdg_locked;
reg [7:0] cnt_lock_zone;

reg signed [15:0] rise_th_high;
reg [7:0] rise_th_width;
reg [7:0] rise_cnt_width;
reg [7:0] rise_cnt_below;
wire rise_high_check;
wire rise_width_check;
wire rise_below_check;
reg rise_invalid_edge;
reg rise_turn_big;
reg rise_turn_small;

reg signed [15:0] fall_th_high;
reg [7:0] fall_th_width;
reg [7:0] fall_cnt_width;
reg [7:0] fall_cnt_below;
wire fall_high_check;
wire fall_width_check;
wire fall_below_check;
reg fall_invalid_edge;
reg fall_turn_big;
reg fall_turn_small;

reg [15:0] cnt_wave_point;
reg signed [15:0] cache_sub_data;

always@(posedge clk_i,negedge rst_n_i)
	begin
	if(!rst_n_i)
		begin
		delay_in_rise <= 1'b0;
		delay_in_fall <= 1'b0;
		delay_locked <= 1'b0;
		cache_sub_data <= 16'd0;
		end
	else
		begin
		delay_in_rise <= flag_in_rise;
		delay_in_fall <= flag_in_fall;
		delay_locked <= flag_locked;
		cache_sub_data <= sub_data_i;
		end
	end
	
assign ndg_in_rise = ((~flag_in_rise) & delay_in_rise) & (~rise_invalid_edge);
assign ndg_in_fall = ((~flag_in_fall) & delay_in_fall) & (~fall_invalid_edge);
assign pdg_in_rise = flag_in_rise & (~delay_in_rise);
assign pdg_in_fall = flag_in_fall & (~delay_in_fall);
assign pdg_locked = flag_locked & (~delay_locked);

//上升沿边沿判断
assign rise_high_check = (sub_data_i > rise_th_high);
assign rise_width_check = (rise_cnt_width >= rise_th_width); 
assign rise_below_check = (rise_cnt_below >= SET_RISE_WIDTH);

reg signed [15:0] snap_rise_start;
reg signed [15:0] rise_most_high;
wire signed [15:0] rise_sub_high;
wire rise_check_high;
wire rise_check_width;

always@(posedge clk_i,negedge rst_n_i)
	begin
	if(!rst_n_i)
		begin
		snap_rise_start <= 16'd0;
		rise_most_high <= 16'd0;
		end
	else
		begin
		if(pdg_in_rise)
			begin
			snap_rise_start <= data_i;
			end
		if(ndg_in_rise & flag_locked)
			begin
			rise_most_high <= (rise_sub_high >>> 1);
			end
		end
	end
assign rise_sub_high = data_i - snap_rise_start;
assign rise_check_width = rise_cnt_width > (flag_locked?SET_EDGE_WIDTH:SET_LOCK_NOISE);
assign rise_check_high = flag_locked & (rise_sub_high < rise_most_high);

always@(posedge clk_i,negedge rst_n_i)
	begin
	if(!rst_n_i)
		begin
		flag_in_rise <= 1'b0;
		rise_cnt_width <= 8'd0;
		rise_cnt_below <= 8'd0;
		rise_invalid_edge <= 1'b0;
		rise_turn_big <= 1'b0;
		rise_turn_small <= 1'b0;
		end
	else
		begin
		if(rise_high_check)
			begin
			rise_invalid_edge <= 1'b0;
			rise_turn_big <= 1'b0;
			rise_turn_small <= 1'b0;
			rise_cnt_below <= 8'd0;
			if(rise_width_check)
				begin
				flag_in_rise <= 1'b1;
				end
			if(rise_cnt_width < SET_WIDTH_MAX)
				begin
				rise_cnt_width <= rise_cnt_width + 8'd1;
				end
			end
		else
			begin
			if(rise_below_check)
				begin
				if(flag_in_rise)	//只执行一次
					begin
					flag_in_rise <= 1'b0;
					//判断是否为无效边沿
					if(rise_check_high | rise_check_width)
						begin
						rise_invalid_edge <= 1'b1;
						end
					if(rise_th_width > (rise_cnt_width >> 1))
						begin
						rise_turn_small <= 1'b1;
						end
					else if(rise_th_width < (rise_cnt_width >> 3))
						begin
						rise_turn_big <= 1'b1;
						end
					end
				else
					begin
					rise_cnt_width <= 8'd0;
					end
				end
			else
				begin
				rise_cnt_below <= rise_cnt_below + 8'd1;
				end
			end
		end
	end
	
//下降沿边沿判断
assign fall_high_check = (sub_data_i < fall_th_high);
assign fall_width_check = (fall_cnt_width >= fall_th_width); 
assign fall_below_check = (fall_cnt_below >= SET_FALL_WIDTH);

reg signed [15:0] snap_fall_start;
reg signed [15:0] fall_most_high;
wire signed [15:0] fall_sub_high;
wire fall_check_high;
wire fall_check_width;

always@(posedge clk_i,negedge rst_n_i)
	begin
	if(!rst_n_i)
		begin
		snap_fall_start <= 16'd0;
		fall_most_high <= 16'd0;
		end
	else
		begin
		if(pdg_in_fall)
			begin
			snap_fall_start <= data_i;
			end
		if(ndg_in_fall & flag_locked)
			begin
			fall_most_high <= (fall_sub_high >>> 1);
			end
		end
	end
assign fall_sub_high = data_i - snap_fall_start;
assign fall_check_width = fall_cnt_width > (flag_locked?SET_EDGE_WIDTH:SET_LOCK_NOISE);
assign fall_check_high = flag_locked & (fall_sub_high > fall_most_high);

always@(posedge clk_i,negedge rst_n_i)
	begin
	if(!rst_n_i)
		begin
		flag_in_fall <= 1'b0;
		fall_cnt_width <= 8'd0;
		fall_cnt_below <= 8'd0;
		fall_invalid_edge <= 1'b0;
		fall_turn_big <= 1'b0;
		fall_turn_small <= 1'b0;
		end
	else
		begin
		if(fall_high_check)
			begin
			fall_invalid_edge <= 1'b0;
			fall_turn_big <= 1'b0;
			fall_turn_small <= 1'b0;
			fall_cnt_below <= 8'd0;
			if(fall_width_check)
				begin
				flag_in_fall <= 1'b1;
				end
			if(fall_cnt_width < SET_WIDTH_MAX)
				begin
				fall_cnt_width <= fall_cnt_width + 8'd1;
				end
			end
		else
			begin
			if(fall_below_check)
				begin
				if(flag_in_fall)	//只执行一次
					begin
					flag_in_fall <= 1'b0;
					if(fall_check_high | fall_check_width)
						begin
						fall_invalid_edge <= 1'b1;
						end
					if(fall_th_width > (fall_cnt_width >> 1))
						begin
						fall_turn_small <= 1'b1;
						end
					else if(fall_th_width < (fall_cnt_width >> 3))
						begin
						fall_turn_big <= 1'b1;
						end
					end
				else
					begin
					fall_cnt_width <= 8'd0;
					end
				end
			else
				begin
				fall_cnt_below <= fall_cnt_below + 8'd1;
				end
			end
		end
	end
	
//动态阈值控制
//波形开始时设定一段采集时间尽量去除杂波影响
always@(posedge clk_i,negedge rst_n_i)
	begin
	if(!rst_n_i)
		begin
		cnt_lock_zone <= 8'd0;
		flag_locked <= 1'b0;
		end
	else
		begin		
		if(cnt_lock_zone < SET_LOCK_ZONE)
			begin
			cnt_lock_zone <= cnt_lock_zone + 8'd1;
			end
		else
			begin
			flag_locked <= 1'b1;
			end
		end
	end

//最大值跟踪	
reg [15:0] snap_rise_point;
reg [15:0] snap_fall_point;
reg signed [15:0] rise_high_max;
reg signed [15:0] fall_high_max;
reg signed [15:0] rise_lock_max;
reg signed [15:0] fall_lock_max;

always@(posedge clk_i,negedge rst_n_i)
	begin
	if(!rst_n_i)
		begin
		rise_high_max <= 16'd0;
		fall_high_max <= 16'd0;
		snap_rise_point <= 16'd0;
		snap_fall_point <= 16'd0;
		end
	else
		begin
		if(flag_in_rise)
			begin
			if(rise_high_max < cache_sub_data)
				begin
				rise_high_max <= cache_sub_data;
				snap_rise_point <= cnt_wave_point;
				end
			end
		else
			begin
			rise_high_max <= 16'd0;
			end
			
		if(flag_in_fall)
			begin
			if(fall_high_max > cache_sub_data)
				begin
				fall_high_max <= cache_sub_data;
				snap_fall_point <= cnt_wave_point;
				end
			end
		else
			begin
			fall_high_max <= 16'd0;
			end
		end
	end

always@(posedge clk_i,negedge rst_n_i)
	begin
	if(!rst_n_i)
		begin
		rise_lock_max <= 16'd0;
		fall_lock_max <= 16'd0;
		end
	else
		begin
		if(~flag_locked)
			begin
			if(ndg_in_rise)
				begin
				rise_lock_max <= rise_high_max;
				end
			if(ndg_in_fall)
				begin
				fall_lock_max <= fall_high_max;
				end
			end
		end
	end

//更新上升阈值	
wire signed [15:0] rise_change_step;
wire signed [15:0] fall_change_step;
reg [1:0] cnt_rise_tb;
reg [1:0] cnt_rise_ts;
reg [1:0] cnt_fall_tb;
reg [1:0] cnt_fall_ts;

assign rise_change_step = (rise_th_high >>> 2); //步进长度为最大值的1/8
assign fall_change_step = (fall_th_high >>> 2); //步进长度原有阈值的1/8
always@(posedge clk_i,negedge rst_n_i)
	begin
	if(!rst_n_i)
		begin
		rise_th_high <= 16'd0;
		rise_th_width <= 8'd0;
		fall_th_high <= 16'd0;
		fall_th_width <= 8'd0;
		cnt_rise_tb <= 2'd0;
		cnt_rise_ts <= 2'd0;
		cnt_fall_tb <= 2'd0;
		cnt_fall_ts <= 2'd0;
		end
	else
		begin
		if(pdg_locked)
			begin
			rise_th_high <= (rise_lock_max > SET_DEF_MIN_HIGH)?
								SET_DEF_MIN_HIGH : (rise_lock_max + 16'd10);
			fall_th_high <= (fall_lock_max < (16'd0 - SET_DEF_MIN_HIGH)) ? 
								(16'd0 - SET_DEF_MIN_HIGH) : (fall_lock_max - 16'd10); 
			rise_th_width <= SET_RISE_WIDTH;
			fall_th_width <= SET_FALL_WIDTH;			
			end
		else
			begin
			if(flag_locked)
				begin
				if(ndg_in_rise)
					begin
					if(rise_turn_big)
						begin
						cnt_rise_ts <= 2'd0;
						if(cnt_rise_tb < 2'd3) 
							cnt_rise_tb <= cnt_rise_tb + 2'd1;
						else
							begin
							cnt_rise_tb <= 2'd0;
							rise_th_high <= rise_th_high + rise_change_step;
							end
						end
					else if(rise_turn_small)
						begin
						cnt_rise_tb <= 2'd0;
						if(cnt_rise_ts < 2'd3)
							cnt_rise_ts <= cnt_rise_ts + 2'd1;
						else
							begin
							cnt_rise_ts <= 2'd0;
							rise_th_high <= rise_th_high - rise_change_step;
							end
						end
					else
						begin
						cnt_rise_tb <= 2'd0;
						cnt_rise_ts <= 2'd0;
						end
					end
					
				if(ndg_in_fall)
					begin
					if(fall_turn_big)
						begin
						cnt_fall_ts <= 2'd0;
						if(cnt_fall_tb < 2'd3) 
							cnt_fall_tb <= cnt_fall_tb + 2'd1;
						else
							begin
							cnt_fall_tb <= 2'd0;
							fall_th_high <= fall_th_high + fall_change_step;
							end
						end
					else if(fall_turn_small)
						begin
						cnt_fall_tb <= 2'd0;
						if(cnt_fall_ts < 2'd3)
							cnt_fall_ts <= cnt_fall_ts + 2'd1;
						else
							begin
							cnt_fall_ts <= 2'd0;
							fall_th_high <= fall_th_high - fall_change_step;
							end
						end
					else
						begin
						cnt_fall_tb <= 2'd0;
						cnt_fall_ts <= 2'd0;
						end
					end
				end
			end
		end
	end
	
//输出控制

//计算当sub_data_i最大值时的时间间隔，将差值最大的点视为边沿判断
reg flag_ready_cnt;
reg [15:0] snap_last_edge;

always@(posedge clk_i,negedge rst_n_i)
	begin
	if(!rst_n_i)
		begin
		flag_ready_cnt <= 1'b0;
		cnt_wave_point <= 16'd0;
		snap_last_edge <= 16'd0;
		rise_edge_o <= 1'b0;
		fall_edge_o <= 1'b0;
		gap_edge_o <= 16'd0;
		end
	else
		begin
		if(flag_locked)
			begin
			rise_edge_o <= ndg_in_rise;
			fall_edge_o <= ndg_in_fall;
			if(ndg_in_rise | ndg_in_fall)
				begin
				flag_ready_cnt <= 1'b1;
				if(ndg_in_rise)
					begin
					gap_edge_o <= snap_rise_point - snap_last_edge;
					snap_last_edge <= snap_rise_point;
					end
				else
					begin
					gap_edge_o <= snap_fall_point - snap_last_edge;
					snap_last_edge <= snap_fall_point;
					end
				end
			
			if(flag_ready_cnt)
				begin
				cnt_wave_point <= cnt_wave_point + 16'd1;
				end		
			end
		end
	end
	
endmodule

