/***************************
File 		: 	Wave_Detect.v
Project 	: 	RFID
Author 	: 	zhangqi
Time 		: 	20170425
Function : 	检测有效信号，根据前道信号101010...以及脉宽检测有效信号；
***************************/
module	Wave_Detect(
			clk_i,
			rst_n,
			
			set_rate_i,
			
			rise_valid_i,
			fall_valid_i,
			gap_point_i,
			
			wave_enable_o
			);

input wire 			clk_i;
input wire 			rst_n;

input wire [8:0]	t_point_big_i;
input wire [8:0]	t_point_small_i;

input wire 			rise_valid_i;
input wire 			fall_valid_i;
input wire [8:0]	gap_point_i;

output reg 			wave_enable_o;


////////////////////////////
reg [4:0] shift_bit;
reg flag_edge_value;
reg flag_detect;
reg [4:0] cnt_edge_valid;

wire edge_valid_half;  //根据脉宽判断边沿是否有效
wire edge_valid_full;
reg [7:0] pulse_init;
reg [8:0] half_point_big;
reg [8:0] half_point_small;
reg [8:0] full_point_big;
reg [8:0] full_point_small;

assign edge_valid_half = ((gap_point_i >= half_point_small) && (gap_point_i <= half_point_big));
assign edge_valid_full = ((gap_point_i >= full_point_small) && (gap_point_i <= full_point_big));


//反向链路速率 64/137.14/174.55/320/128/274.29/349.09/640K
//LUT = fclk / speed / 2;
always@(set_rate_i)
	begin
	case(set_rate_i)
	3'd0:
		begin
		pulse_init = 8'd195;
		half_point_big <= 9'd258;
		half_point_small <= 9'd140;
		full_point_big <= 9'd507;
		full_point_small <= 9'd273;
		end
	3'd1:
		begin
		pulse_init = 8'd91;
		half_point_big <= 9'd120;
		half_point_small <= 9'd65;
		full_point_big <= 9'd236;
		full_point_small <= 9'd127;
		end
	3'd2:
		begin
		pulse_init = 8'd72;
		half_point_big <= 9'd95;
		half_point_small <= 9'd51;
		full_point_big <= 9'd186;
		full_point_small <= 9'd100;
		end
	3'd3:
		begin
		pulse_init = 8'd39;
		half_point_big <= 9'd52;
		half_point_small <= 9'd28;
		full_point_big <= 9'd101;
		full_point_small <= 9'd54;
		end
	3'd4:
		begin
		pulse_init = 8'd98;
		half_point_big <= 9'd129;
		half_point_small <= 9'd70;
		full_point_big <= 9'd253;
		full_point_small <= 9'd136;
		end
	3'd5:
		begin
		pulse_init = 8'd46;
		half_point_big <= 9'd60;
		half_point_small <= 9'd32;
		full_point_big <= 9'd118;
		full_point_small <= 9'd63;
		end
	3'd6:
		begin
		pulse_init = 8'd36;
		half_point_big <= 9'd47;
		half_point_small <= 9'd25;
		full_point_big <= 9'd93;
		full_point_small <= 9'd50;
		end
	3'd7:
		begin
		pulse_init = 8'd20;
		half_point_big <= 9'd26;
		half_point_small <= 9'd14;
		full_point_big <= 9'd50;
		full_point_small <= 9'd27;
		end
	endcase
	end

always @(posedge clk_i, negedge rst_n)
begin
	if(!rst_n)
		begin
		shift_bit <= 5'd0;
		flag_edge_value <= 1'b0;
		flag_detect <= 1'b0;
		cnt_edge_valid <= 5'd0;
		wave_enable_o <= 1'b0;
		end
	else
		begin
		if(!flag_detect)
			begin
			if(cnt_edge_valid < )
				begin
				if(edge_valid && (rise_valid_i | fall_valid_i))
					begin
					if(rise_valid_i && (flag_edge_value == 1'b0))
						begin
						cnt_edge_valid <= cnt_edge_valid + 1'b1;
						flag_edge_value <= 1'b1;
						end
					else if(fall_valid_i && (flag_edge_value == 1'b1))
						begin
						cnt_edge_valid <= cnt_edge_valid + 1'b1;
						flag_edge_value <= 1'b0;
						end
					else 
						begin
						cnt_edge_valid <= 5'd0;
						end
					end
				else if(!edge_valid)
					begin
					shift_bit <= 5'd0;
					end
				end
			else
				begin
				flag_detect <= 1'b1;
				end
			end
		else
			begin
			wave_enable_o <= 1'b1;
			end
		end
end

endmodule
