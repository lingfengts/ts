//created by zhouhang 
//脉宽同步与频率修正
//v1.0.2013

module Pulse_Sync(
	clk_i,
	rst_n_i,
	
	set_rate_i,
	set_lock_num_i,
	set_lock_double_i,
	
	set_decode_i,
	form_sync_i,
	boot_sync_i,
	
	rise_valid_i,
	fall_valid_i,
	gap_point_i,
	
	pulse_sync_o,
	err_lost_sync_o,
	bit_valid_o,
	bit_data_o
);

input wire clk_i;
input wire rst_n_i;

input wire [8:0] set_rate_i;
input wire [2:0] set_lock_num_i;
input wire set_lock_double_i;
input wire set_decode_i;	//解码模式 0：FM0 1：MILLER
input wire boot_sync_i;
input wire form_sync_i;

input wire rise_valid_i;
input wire fall_valid_i;
input wire [15:0] gap_point_i;

output wire pulse_sync_o;
output reg err_lost_sync_o;
output reg bit_valid_o;
output reg bit_data_o; 

reg flag_pulse_lock;
reg [2:0] cnt_pulse_check;
reg [8:0] pulse_width;
wire edge_valid;

assign edge_valid = rise_valid_i | fall_valid_i;

reg [15:0] div_num;
wire [15:0] div_q;
wire [8:0] div_remain;
	
Pulse_Sync_Div M_Pulse_Sync_Div(
	.denom(pulse_width),
	.numer(div_num),
	.quotient(div_q),
	.remain(div_remain)
	);

`define FSM_PS_RESET	3'd0
`define FSM_PS_IDLE	3'd1
`define FSM_PS_CHECK 3'd2
`define FSM_PS_CORRECT	3'd3
`define FSM_PS_OUTPUT	3'd4

reg [2:0] current_state;
reg [15:0] last_gap;
wire [8:0] pulse_offset;
wire flag_offset_big;
wire flag_offset_little;
wire flag_pulse_valid;
wire [3:0] pulse_num;
wire lock_num_ready;
reg last_edge;
reg current_edge;
reg flag_lost_once;
reg [1:0] status_edge;
reg [15:0] shift_value;
reg [3:0] shift_length;
reg flag_first_edge;
wire flag_diff_edge;
wire flag_correct_width;
wire flag_lock_width;
wire flag_in_range;
wire flag_err_edge;
reg flag_odd;
reg flag_add_odd;

assign pulse_offset = (pulse_width >> 1);	// +- 1/2脉宽
assign flag_offset_little = (div_remain < pulse_offset);
assign flag_offset_big = (div_remain > (pulse_width - pulse_offset));
assign flag_in_range = ((div_q != 16'd0) & flag_offset_little) | flag_offset_big;
assign flag_err_edge = (pulse_num == 16'd1) & (last_edge ~^ current_edge);
assign flag_pulse_valid = flag_in_range & (~flag_err_edge);
assign flag_diff_edge = status_edge[1] ^ status_edge[0];
assign flag_correct_width = (pulse_num == 4'd1);
assign lock_num_ready = set_lock_double_i ? (pulse_num == 4'd2) : (pulse_num == 4'd1);
assign flag_lock_width = lock_num_ready & flag_pulse_valid;
assign pulse_sync_o = flag_pulse_lock;
assign pulse_num = flag_offset_big ? (div_q[3:0] + 4'd1) : div_q[3:0];

always@(posedge clk_i,negedge rst_n_i)
	begin
	if(!rst_n_i)
		begin
		current_state <= `FSM_PS_RESET;
		pulse_width <= 9'd0;
		cnt_pulse_check <= 3'd0;
		flag_pulse_lock <= 1'b0;
		div_num <= 16'd0;
		last_gap <= 16'd0;
		current_edge <= 1'b0;
		last_edge <= 1'b0;
		flag_lost_once <= 1'b0;
		status_edge <= 2'd0;
		shift_value <= 16'd0;
		shift_length <= 4'd0;
		err_lost_sync_o <= 1'b0;
		bit_valid_o <= 1'b0;
		bit_data_o <= 1'b0;
		flag_first_edge <= 1'b0;
		flag_add_odd <= 1'b0;
		end
	else
		begin
		case(current_state)
		`FSM_PS_RESET:
			begin
			current_state <= `FSM_PS_IDLE;
			pulse_width <= set_rate_i;
			cnt_pulse_check <= 3'd0;
			end
		`FSM_PS_IDLE:
			begin
			if(edge_valid)
				begin
				current_state <= `FSM_PS_CHECK;
				div_num <= gap_point_i + last_gap; 
				if(rise_valid_i)
					begin
					current_edge <= 1'b1;
					end
				else
					begin
					current_edge <= 1'b0;
					end
				end
			end
		`FSM_PS_CHECK:
			begin
			if(flag_pulse_lock)
				begin
				if(flag_pulse_valid)
					begin
					current_state <= `FSM_PS_CORRECT;
					end
				else
					begin
					current_state <= `FSM_PS_IDLE;
					end
				end
			else
				begin
				current_state <= `FSM_PS_IDLE;
				if(flag_lock_width)
					begin
					if(cnt_pulse_check < set_lock_num_i)
						begin
						cnt_pulse_check <= cnt_pulse_check + 3'd1;
						end
					else
						begin
						flag_pulse_lock <= 1'b1;
						end
					end
				else
					begin
					cnt_pulse_check <= 3'd0;
					end
				end
			
			if(flag_pulse_valid | (flag_first_edge == 1'b0))
				begin
				flag_add_odd <= 1'b1;
				flag_first_edge <= 1'b1;
				last_gap <= 16'd0;
				last_edge <= current_edge;
				status_edge <= {last_edge,current_edge};
				flag_lost_once <= 1'b0;
				end
			else
				begin
				last_gap <= gap_point_i;
				if(flag_pulse_lock)
					begin
					if(flag_lost_once)
						begin
						err_lost_sync_o <= 1'b1;
						end
					else
						begin
						flag_lost_once <= 1'b1;
						end
					end
				end
			end
		`FSM_PS_CORRECT:
			begin
			current_state <= `FSM_PS_OUTPUT;
			flag_add_odd <= 1'b0;
			//边沿修正
			shift_length <= pulse_num;
			case(pulse_num)
			4'd1:
				begin
				shift_value <= {8{(~status_edge[0]),status_edge[0]}};
				end
			4'd3:
				begin
				if(flag_diff_edge)
					begin
					shift_value <= {8{(~status_edge[0]),status_edge[0]}};
					end
				else
					begin
					if(set_decode_i)
						begin
						if(flag_odd)
							begin
							shift_value <= {13'd0,status_edge[0],{2{~status_edge[0]}}};
							end
						else
							begin
							shift_value <= {8{(~status_edge[0]),status_edge[0]}};
							end
						end
					else
						begin
						if(boot_sync_i)
							begin
							if(flag_odd)
								begin
								shift_value <= {8{(~status_edge[0]),status_edge[0]}};
								end
							else
								begin
								shift_value <= {13'd0,status_edge[0],{2{~status_edge[0]}}};
								end
							end
						else
							begin
							if(&status_edge)
								begin
								shift_value <= {8{(~status_edge[0]),status_edge[0]}};
								end
							else
								begin
								shift_value <= {13'd0,status_edge[0],{2{~status_edge[0]}}};
								end
							end
						end
					end
				end
			4'd4:
				begin
				if((~set_decode_i) & (~boot_sync_i) & (~flag_diff_edge))
					begin
					shift_value <= {12'd0,status_edge[0],{3{~status_edge[0]}}};
					end
				else
					begin
					shift_value <= {8{status_edge[0],(~status_edge[0])}};
					end
				end
			default:
				begin
				shift_value <= {8{status_edge[0],(~status_edge[0])}};
				end
			endcase
			
			//脉宽控制修正
			if(flag_correct_width)
				begin
				if(pulse_width > gap_point_i)
					begin
					if((pulse_width - gap_point_i) > 9'd4)
						begin
						pulse_width <= pulse_width - 9'd1;
						end
					end
				else
					begin
					if((gap_point_i - pulse_width) > 9'd4)
						begin
						pulse_width <= pulse_width + 9'd1;
						end
					end
				end
			end
		`FSM_PS_OUTPUT:
			begin
			if(shift_length)
				begin
				shift_length <= shift_length - 4'd1;
				bit_valid_o <= 1'b1;
				bit_data_o <= shift_value[0];
				shift_value <= (shift_value >> 1);
				end
			else
				begin
				current_state <= `FSM_PS_IDLE;
				bit_valid_o <= 1'b0;
				bit_data_o <= 1'b0;
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


