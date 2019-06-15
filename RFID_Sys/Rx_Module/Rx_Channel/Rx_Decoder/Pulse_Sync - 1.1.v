//created by zhouhang 
//脉宽同步与频率修正
//v1.0.0213
//v1.1.0222 将判断范围分为两个区间，确信区间和质疑区间
//v1.2.0308 修改set_rate_i宽度，统一接口，使用查表得到设定值

module Pulse_Sync(
	clk_i,
	rst_n_i,
	
	set_rate_i,
	set_decode_i,
	
	form_sync_i,
	boot_sync_i,
	
	rise_valid_i,
	fall_valid_i,
	gap_point_i,
	threshold_peak_i,
	bit_even_i,
	form_right_i,
	pulse_width_i,
	
	pulse_sync_o,
	bit_valid_o,
	bit_data_o
);

input wire clk_i;
input wire rst_n_i;

input wire [2:0] set_rate_i;
input wire set_decode_i;	//解码模式 0：FM0 1：MILLER

input wire boot_sync_i;
input wire form_sync_i;

input wire rise_valid_i;
input wire fall_valid_i;
input wire [15:0] gap_point_i;
input wire [15:0] threshold_peak_i;
input wire bit_even_i;
input wire form_right_i;
input wire [9:0] pulse_width_i;

output reg pulse_sync_o;
output reg bit_valid_o;
output reg bit_data_o; 

reg [8:0] pulse_width;
reg [15:0] point_pluse_cnt;
wire edge_valid;
wire edge_bit;
wire [11:0] pulse_point_o;

//////////////////////
Point_Judge			M_Point_Judge(
						.clk_i(clk_i),
						.rst_n(rst_n_i),
						
						.De_enable(),
						
						.flag_edg_rise(rise_valid_i),
						.flag_edg_fall(fall_valid_i),
						
						.threshold_peak(threshold_peak_i),
						.cnt_point_ptr({2'h0,pulse_width_i}),
						
						.edge_valid(edge_valid),
						.edge_bit(edge_bit),
						.pulse_point_o(pulse_point_o)
						);

//assign edge_valid = rise_valid_i | fall_valid_i;

reg [15:0] div_num;
wire [15:0] div_q;
wire [8:0] div_remain;
	
Pulse_Sync_Div M_Pulse_Sync_Div(
	.aclr(~rst_n_i),
	.clock(clk_i),
	.denom(pulse_width_i),
	.numer(div_num),
	.quotient(div_q),
	.remain(div_remain)
	);

`define FSM_PS_RESET	3'd0
`define FSM_PS_IDLE	3'd1
`define FSM_PS_PIPE	3'd2
`define FSM_PS_CHECK 3'd3
`define FSM_PS_CORRECT	3'd4
`define FSM_PS_OUTPUT	3'd5

reg [2:0] current_state;
reg [15:0] last_gap;
wire [8:0] offset_wide;
wire [8:0] offset_nar;
reg [4:0] pulse_num;
reg current_edge;
reg [2:0] status_edge;
reg [2:0] edg_value;
reg [15:0] shift_value;
reg [4:0] shift_length;
wire flag_diff_edge;
wire flag_correct_width;
reg flag_odd;
reg flag_add_odd;
reg [2:0] cnt_sync;
wire check_sync;
reg flag_edg_dly;
reg flag_edg_add_front;  //漏边沿时添加边沿标志，主要针对3倍脉宽
reg flag_edg_add_back;
reg flag_edg_small;
reg flag_bit_valid;
reg [1:0] bit_valid_delay;

////////////////////////////////////
reg [9:0] gap_error;  //脉宽累积误差
reg [11:0] point_pluse_cache[4:0];
reg flag_point_cache;
wire [15:0] point_div_front;
wire [15:0] point_div_last;
wire [15:0] div_q_front;
wire [15:0] div_q_last;
wire [8:0] div_remain_front;
wire [8:0] div_remain_last;
wire range_less_front;
wire range_more_front;
wire range_big_front;
wire range_small_front;
wire range_less_last;
wire range_more_last;
wire range_big_last;
wire range_small_last;
reg [4:0] pulse_num_front;
reg [4:0] pulse_num_last;

assign range_less_front = (div_remain_front > (offset_wide)) & 
							(div_remain_front < (pulse_width_i - offset_nar));
assign range_more_front = (div_remain_front > offset_nar) & 
							(div_remain_front <= offset_wide);
assign range_small_front = (div_remain_front >= (pulse_width_i - offset_nar));
assign range_big_front = (div_remain_front <= offset_nar);

assign range_less_last = (div_remain_last > (offset_wide)) & 
							(div_remain_last < (pulse_width_i - offset_nar));
assign range_more_last = (div_remain_last > offset_nar) & 
							(div_remain_last <= offset_wide);
assign range_small_last = (div_remain_last >= (pulse_width_i - offset_nar));							
assign range_big_last = (div_remain_last <= offset_nar);

///////////////////////////////////////////
reg [2:0] last_edge;
reg flag_rise;
reg flag_fall;

wire range_less;
wire range_more;
wire range_big;
wire range_small;
wire flag_dead_zone;
reg [1:0] last_range_status;	//1bit: last small 0bit:last big

assign offset_wide = (pulse_width_i >> 1);	// +- 1/2脉宽
assign offset_nar = (pulse_width_i >> 2);	//1/4
assign range_less = (div_remain > (offset_wide)) & 
							(div_remain < (pulse_width_i - offset_nar));
assign range_more = (div_remain > offset_nar) & 
							(div_remain <= offset_wide);
assign range_small = (div_remain >= (pulse_width_i - offset_nar));							
assign range_big = (div_remain <= offset_nar);
assign flag_dead_zone = (div_q == 16'd0) & (range_big | range_more);
assign flag_diff_edge = edg_value[2] ^ edg_value[1];
assign flag_correct_width = (pulse_num == 5'd1);
assign check_sync = (pulse_num == 16'd1) | (pulse_num == 16'd2);

reg [7:0] pulse_init;
//反向链路速率 64/137.14/174.55/320/128/274.29/349.09/640K
//LUT = fclk / speed / 2;
always@(set_rate_i)
	begin
	case(set_rate_i)
	3'd0:
		pulse_init = 8'd195;
	3'd1:
		pulse_init = 8'd91;
	3'd2:
		pulse_init = 8'd72;
	3'd3:
		pulse_init = 8'd39;
	3'd4:
		pulse_init = 8'd98;
	3'd5:
		pulse_init = 8'd46;
	3'd6:
		pulse_init = 8'd36;
	3'd7:
		pulse_init = 8'd20;
	endcase
	end


always @(posedge clk_i, negedge rst_n_i)
begin
	if(!rst_n_i)
		begin
		last_edge <= 3'd0;
		flag_rise <= 1'b0;
		flag_fall <= 1'b0;
		end
	else
		begin
		if(rise_valid_i)
			begin
			flag_rise <= 1'b1;
			flag_fall <= 1'b0;
			end
		else if(fall_valid_i)
			begin
			flag_rise <= 1'b0;
			flag_fall <= 1'b1;
			end
		
		if(edge_valid)
			begin
			if(flag_rise)
				last_edge <= {last_edge[1:0],1'b1};  //当前为上升沿
			else if(flag_fall)
				last_edge <= {last_edge[1:0],1'b0};  //当前为下降沿
			end
		end
end	

/**********************************************/
always @(posedge clk_i, negedge rst_n_i)
begin
	if(!rst_n_i)
		begin
		point_pluse_cache[3] <= 12'd0;
		point_pluse_cache[2] <= 12'd0;
		point_pluse_cache[1] <= 12'd0;
		point_pluse_cache[0] <= 12'd0;
		end
	else if(edge_valid)
		begin
		if(!flag_point_cache)
			begin
			point_pluse_cache[4] <= pulse_point_o;
			point_pluse_cache[3] <= point_pluse_cache[4];
			point_pluse_cache[2] <= point_pluse_cache[3];
			point_pluse_cache[1] <= point_pluse_cache[2];
			point_pluse_cache[0] <= point_pluse_cache[1];
			end
		else
			begin
			point_pluse_cache[4] <= point_pluse_cache[4] + pulse_point_o;
			end
		end
end	

assign point_div_last = point_pluse_cache[0] + point_pluse_cache[1] + point_pluse_cache[2] + point_pluse_cache[3];
assign point_div_front = point_div_last + point_pluse_cache[4];
	
Pulse_Sync_Div Pulse_Sync_Div_Front(
	.aclr(~rst_n_i),
	.clock(clk_i),
	.denom(pulse_width_i),
	.numer(point_div_front),
	.quotient(div_q_front),
	.remain(div_remain_front)
	);	
	
Pulse_Sync_Div Pulse_Sync_Div_Last(
	.aclr(~rst_n_i),
	.clock(clk_i),
	.denom(pulse_width_i),
	.numer(point_div_last),
	.quotient(div_q_last),
	.remain(div_remain_last)
	);
	
///////////////////////////////////////////////////////	
always@(posedge clk_i,negedge rst_n_i)
	begin
	if(!rst_n_i)
		begin
		current_state <= `FSM_PS_RESET;
		pulse_width <= 9'd1;
		div_num <= 16'd0;
		pulse_num <= 5'd1;
		last_gap <= 16'd0;
		current_edge <= 1'b0;
		status_edge <= 3'd0;
		edg_value <= 3'd0;
		shift_value <= 16'd0;
		shift_length <= 5'd0;
		bit_valid_o <= 1'b0;
		bit_data_o <= 1'b0;
		flag_add_odd <= 1'b0;
		last_range_status <= 2'd0;
		pulse_sync_o <= 1'b0;
		cnt_sync <= 3'd0;
		flag_edg_dly <= 1'b0;
		flag_edg_add_front <= 1'b0;
		flag_edg_add_back <= 1'b0;
		flag_edg_small <= 1'b0;
		flag_bit_valid <= 1'b0;
		bit_valid_delay <= 2'b0;
		point_pluse_cnt <= 16'd0;
		gap_error <= 9'd0;
		flag_point_cache <= 1'b0;
		end
	else
		begin
		case(current_state)
		`FSM_PS_RESET:
			begin
			current_state <= `FSM_PS_IDLE;
			pulse_width <= pulse_init;
			div_num <= 16'd0;
			pulse_num <= 5'd1;
			last_gap <= 16'd0;
			current_edge <= 1'b0;
			status_edge <= 3'd0;
			edg_value <= 3'd0;
			shift_value <= 16'd0;
			shift_length <= 5'd0;
			bit_valid_o <= 1'b0;
			bit_data_o <= 1'b0;
			flag_add_odd <= 1'b0;
			last_range_status <= 2'd0;
			pulse_sync_o <= 1'b0;
			cnt_sync <= 3'd0;
			flag_edg_dly <= 1'b0;
			flag_edg_add_front <= 1'b0;
			flag_edg_add_back <= 1'b0;
			flag_edg_small <= 1'b0;
			point_pluse_cnt <= 16'd0;
			gap_error <= 9'd0;
			flag_point_cache <= 1'b0;
			end
		`FSM_PS_IDLE:
			begin
			if(edge_valid)
				begin
				current_state <= `FSM_PS_PIPE;
				div_num <= pulse_point_o + last_gap; 
				
				current_edge <= edge_bit;
				end
			end
		`FSM_PS_PIPE:
			begin
			//除法PIPELINE 满足时序
			current_state <= `FSM_PS_CHECK;
			
			end
		`FSM_PS_CHECK:
			begin			
			if(flag_dead_zone)
				begin
				current_state <= `FSM_PS_IDLE;
				last_gap <= pulse_point_o + last_gap;
				flag_point_cache <= 1'b1;
				end
			else if((last_range_status == 2'd0) && (range_more | range_less))  //last_range_status == 2'd0  div_q[3:0] <= 4'd2
				begin
				current_state <= `FSM_PS_IDLE;
				last_gap <= pulse_point_o + last_gap;	
				last_range_status <= {range_less,range_more};
				flag_edg_dly <= 1'b1;
				flag_point_cache <= 1'b1;
				
				if(~flag_edg_dly)
					begin
					edg_value <= {edg_value[1:0],current_edge};
					status_edge <= {current_edge,last_edge[2:1]};
					end
				else
					begin
					edg_value[1:0] <= {edg_value[0],current_edge};
					status_edge[1:0] <= last_edge[2:1];
					end
				
				if((div_q == 16'd1) & range_more)
					flag_edg_small <= 1'b1;  //小于1+1/2
				if(((div_q == 16'd1) & range_less) | ((div_q == 16'd2) & range_more))
					flag_edg_add_front <= 1'b1;  //大于1+1/2，小于2+1/2
				else if((div_q == 16'd2) & range_less)
					flag_edg_add_back <= 1'b1;  //大于于2+1/2，后面添加
				end
			else
				begin
				current_state <= `FSM_PS_CORRECT;
				last_gap <= 16'd0;
				flag_add_odd <= 1'b1;
				
				if(~flag_edg_dly)
					begin
					edg_value <= {edg_value[1:0],current_edge};
					status_edge <= {current_edge,last_edge[2:1]};
					end
				else
					begin
					edg_value[1:0] <= {edg_value[0],current_edge};
					status_edge[1:0] <= last_edge[2:1];
					end
				
				if(range_small | range_big)
					begin
					last_range_status <= 2'd0;
					if(range_small)
						begin
						pulse_num <= div_q[4:0] + 4'd1;
						gap_error <= gap_error + div_remain - pulse_width_i;
						end
					else
						begin
						pulse_num <= div_q[4:0];
						gap_error <= gap_error + div_remain;
						end
					end
				else
					begin
					last_range_status <= 2'd0;
					pulse_num <= div_q[4:0];
					
					gap_error <= gap_error + div_remain;
					end
				end
			end
		`FSM_PS_CORRECT:
			begin
			current_state <= `FSM_PS_OUTPUT;
			flag_add_odd <= 1'b0;
			//边沿修正
//			shift_length <= pulse_num;
			case(pulse_num)
			5'd1:
				begin
				shift_value <= {8{(~status_edge[2]),status_edge[2]}};
				shift_length <= 5'd1;
				end
			5'd2:
				begin
				shift_length <= 5'd2;
				if(status_edge[2] ^ status_edge[0])
					shift_value <= {8{status_edge[2],(status_edge[2])}};	
				else
					shift_value <= {8{(~status_edge[2]),status_edge[2]}};
//				if(set_decode_i)
//					begin
//					if(!form_right_i) //规则正确之前
//						begin
//						if(status_edge[2] ^ status_edge[0])
//							shift_value <= {8{status_edge[2],(status_edge[2])}};	
//						else
//							shift_value <= {8{(~status_edge[2]),status_edge[2]}};
//						end
//					else
//						begin
//						if(bit_even_i)
//							begin
//							shift_value <= {8{(~status_edge[2]),status_edge[2]}};
//							end
//						else
//							begin
//							if(status_edge[2] ^ status_edge[0])
//								shift_value <= {8{status_edge[2],(status_edge[2])}};	
//							else
//								shift_value <= {8{(~status_edge[2]),status_edge[2]}};
//							end
//						end
//					end
//				else
//					begin
//					end
				end
			5'd3:
				begin
				shift_length <= 5'd3;
				if(set_decode_i)
					begin
//					if(!form_right_i) //规则正确之前
//						begin
//						shift_value <= {8{(~status_edge[2]),status_edge[2]}};
//						end
//					else
						begin
						if(status_edge[2] ^ status_edge[0])
							begin
							shift_value <= {8{(~status_edge[2]),status_edge[2]}};
							end
						else
							begin
								if(bit_even_i)
									begin
									shift_value <= {13'd0,{2{~status_edge[2]}},{status_edge[2]}};
									end
								else
									begin
									shift_value <= {13'd0,~status_edge[2],{2{status_edge[2]}}};
									end	
////							if(!flag_edg_dly)
////								begin
//								if(bit_even_i)
//									begin
//									shift_value <= {13'd0,{2{~status_edge[2]}},{status_edge[2]}};
//									end
//								else
//									begin
//									shift_value <= {13'd0,~status_edge[2],{2{status_edge[2]}}};
//									end	
//								end
//							else
//								begin
//								if(flag_edg_small)
//									shift_value <= {13'd0,{2{~status_edge[2]}},{status_edge[2]}};
//								else
//									shift_value <= {13'd0,~status_edge[2],{2{status_edge[2]}}};
//								end
							end
						end
					end
				else
					begin
					if(boot_sync_i)
						begin
						if(flag_diff_edge)
							begin
							shift_value <= {8{(~status_edge[2]),status_edge[2]}};
							end
						else
							begin
							if(flag_odd)
								begin
								shift_value <= {8{(~status_edge[2]),status_edge[2]}};
								end
							else
								begin
								shift_value <= {13'd0,status_edge[2],{2{~status_edge[2]}}};
								end
							end
						end
					else
						begin
						if(&status_edge[2:1])
							begin
							shift_value <= {8{(~status_edge[2]),status_edge[2]}};
							end
						else
							begin
							shift_value <= {13'd0,status_edge[2],{2{~status_edge[2]}}};
							end
						end
					end
				end
			5'd4:
				begin
				if(set_decode_i)
					begin
					if(!form_right_i)
						begin
						shift_value <= {8{~status_edge[2],(status_edge[2])}};
						shift_length <= 5'd4;
						end
					else
						begin
						if(bit_even_i)
							begin
							case(status_edge)
							3'b100,3'b011,3'b110,3'b001 :
								begin
								shift_value <= {12'd0,{status_edge[2]},{2{~status_edge[2]}},{status_edge[2]}};
								shift_length <= 5'd4;
								end
							3'b101,3'b010 :
								begin
								shift_value <= {12'd0,{2{~status_edge[2],status_edge[2]}}};
								shift_length <= 5'd4;
								end
							default:
								begin
								shift_value <= {12'd0,{2{~status_edge[2],status_edge[2]}}};
								shift_length <= 5'd4;
								end
							endcase
							end
						else
							begin
							
							case(status_edge)
							3'b100,3'b011 :
								begin
								if(flag_edg_small)
									shift_value <= {12'd0,{2{status_edge[2]}},~status_edge[2],{status_edge[2]}};
								else
									shift_value <= {12'd0,status_edge[2],~status_edge[2],{2{status_edge[2]}}};
								
								shift_length <= 5'd4;
								end
							3'b101,3'b010 :
								begin
//								shift_value <= {12'd0,status_edge[2],~status_edge[2],{2{status_edge[2]}}};
//								shift_length <= 5'd3;
								shift_value <= {12'd0,{2{~status_edge[2],status_edge[2]}}};
								shift_length <= 5'd4;
								end
							3'b110,3'b001 :
								begin
								if(flag_edg_dly)
									begin
									if(flag_edg_add_back)
										shift_value <= {12'd0,status_edge[2],~status_edge[2],{2{status_edge[2]}}};
									else
										shift_value <= {12'd0,{2{status_edge[2]}},~status_edge[2],{status_edge[2]}};
									end
								else
									shift_value <= {12'd0,status_edge[2],~status_edge[2],{2{status_edge[2]}}};
									
								shift_length <= 5'd4;
								end
							default:
								begin
								shift_value <= {12'd0,{2{~status_edge[2],status_edge[2]}}};
								shift_length <= 5'd4;
								end
							endcase
							end
						end
					end
				else
					begin
					if(flag_diff_edge)
						begin
						shift_value <= {8{status_edge[2],(~status_edge[2])}};
						end
					else
						begin
						if(boot_sync_i)
							begin
							shift_value <= {12'd0,status_edge[2],{2{~status_edge[2]}},status_edge[2]};
							end
						else
							begin
							shift_value <= {12'd0,status_edge[2],{3{~status_edge[2]}}};
							end
						end
					end
				end
			default:
				begin
				shift_length <= pulse_num;
				shift_value <= {8{~status_edge[2],(status_edge[2])}};
//				if(!form_right_i) //规则正确之前
//					begin
//					shift_value <= {8{(~status_edge[2]),status_edge[2]}};
//					end
//				else
//					begin
//					if(status_edge[2] ^ status_edge[0])
//						shift_value <= {8{status_edge[2],(status_edge[2])}};
//					else
//						shift_value <= {8{~status_edge[2],(status_edge[2])}};
//					end
				end
			endcase
			
			//脉宽控制修正
//			if(flag_correct_width)
//				begin
//				if(pulse_width > pulse_point_o)
//					begin
//					if((pulse_width - pulse_point_o) > 9'd4)
//						begin
//						pulse_width <= pulse_width - 9'd1;
//						end
//					end
//				else
//					begin
//					if((pulse_point_o - pulse_width) > 9'd4)
//						begin
//						pulse_width <= pulse_width + 9'd1;
//						end
//					end
//				end
//			else
//				begin
//				end
//				
//			//脉宽锁定检查
//			if(flag_diff_edge & check_sync)
//				begin
//				if(cnt_sync < 3'd3)
//					begin
//					cnt_sync <= cnt_sync + 3'd1;
//					end
//				else
//					begin
//					pulse_sync_o <= 1'b1;
//					end
//				end
//			else
//				begin
//				cnt_sync <= 3'd0;
//				end

			if(~pulse_sync_o)
				begin
				if(flag_correct_width)
					begin
					if(cnt_sync <= 3'd3)
						begin
						cnt_sync <= cnt_sync + 3'd1;
						point_pluse_cnt <= point_pluse_cnt + pulse_point_o; 
						end
					else
						begin
						pulse_sync_o <= 1'b1;
						end
					end
				else
					begin
					cnt_sync <= 3'd0;
					point_pluse_cnt <= 16'd0;
					end
				end
			else
				begin
				pulse_width <= point_pluse_cnt >> 2;
				end
			
			end
		`FSM_PS_OUTPUT:
			begin
			if(shift_length)
				begin
				if(!flag_bit_valid)
					begin
					shift_length <= shift_length - 5'd1;
					bit_valid_o <= 1'b1;
					
					shift_value <= (shift_value >> 1);
					flag_bit_valid <= 1'b1;
					bit_valid_delay <= 2'b0;
					
					bit_data_o <= shift_value[0];
					end
				else
					begin
					bit_valid_o <= 1'b0;
					flag_bit_valid <= 1'b0;
//					if(bit_valid_delay <= 2'd1)
//						bit_valid_delay <= bit_valid_delay + 1'b1;
//					else
//						flag_bit_valid <= 1'b0;
					end
				end
			else
				begin
				current_state <= `FSM_PS_IDLE;
				bit_valid_o <= 1'b0;
//				bit_data_o <= 1'b0;
				flag_edg_add_front <= 1'b0;
				flag_edg_add_back <= 1'b0; 
				flag_edg_small <= 1'b0;
				flag_bit_valid <= 1'b0;
				flag_edg_dly <= 1'b0;
				flag_point_cache <= 1'b0;
				
//				if(flag_edg_dly)
//					status_edge <= {status_edge[1:0],current_edge};
//				flag_edg_dly <= 1'b0;
				end
			end
		default:
			begin
			current_state <= `FSM_PS_RESET;
			end
		endcase
		end
	end

reg delay_form_sync;
wire pdg_form_sync;
always@(posedge clk_i,negedge rst_n_i)
	begin
	if(!rst_n_i)
		begin
		delay_form_sync <= 1'b0;
		end
	else
		begin
		delay_form_sync <= form_sync_i;
		end
	end
assign pdg_form_sync = form_sync_i & (~delay_form_sync);
	
always@(posedge clk_i,negedge rst_n_i)
	begin
	if(!rst_n_i)
		begin
		flag_odd <= 1'b0;
		end
	else
		begin
		if(pdg_form_sync)
			begin
			flag_odd <= 1'b0;
			end
		else
			begin
			if(flag_add_odd)
				begin
				flag_odd <= flag_odd + pulse_num;
				end
			end
		end
	end

endmodule
