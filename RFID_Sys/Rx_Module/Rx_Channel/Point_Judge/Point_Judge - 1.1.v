/***************************
File 		: Point_Judge.v
Project 	: RFID
Author 		: zhangqi
Time 		: 20170421
Function 	: 根据边沿以及极值判断边沿是否有效并输出结果。	
***************************/
module	Point_Judge(
		clk_i,
		rst_n,
		
		De_enable,
		
		flag_edg_rise,
		flag_edg_fall,
		
		threshold_peak,
		cnt_point_ptr,
		
		edge_valid,
		edge_bit,
		pulse_point_o
		);
		
		
parameter ASK_WIDTH = 16;	
		
		
input wire 					clk_i;
input wire 					rst_n;

input wire					De_enable;

input wire 					flag_edg_rise;
input wire 					flag_edg_fall;

input wire [ASK_WIDTH-1:0] 	threshold_peak;
input wire [11:0]			cnt_point_ptr;

output wire 				edge_valid;
output wire 				edge_bit;
output wire [11:0]		pulse_point_o;




/************************************************/
//根据相邻两个边沿输出一个状态，判断当前边沿是否有效 连续两个相同边沿视为无效
reg [1:0] state_edg;
reg flag_edg;  //检测到边沿

always @(posedge clk_i, negedge rst_n)
begin
	if(~rst_n)
		begin
		state_edg <= 2'b0;
		flag_edg <= 1'b0;
		end
	else
		begin
		if(flag_edg_rise)
			begin
			state_edg <= {state_edg[0],1'b1};
			flag_edg <= 1'b1;
			end
		else if(flag_edg_fall)
			begin
			state_edg <= {state_edg[0],1'b0};
			flag_edg <= 1'b1;
			end
		else
			flag_edg <= 1'b0;
		end
end




/********************************************************************/
//根据以上边沿状态判断边沿是否有效
reg [3:0] WAVE_JUDGE;  //状态机
reg [11:0] cnt_point;  //周期计数  每次边沿时进行计数

reg flag_edg_suc;
reg flag_edg_err;
reg edg_err_valid; //有效的错误边沿，连续两个相同边沿都有效时
reg flag_peak_en;  //两个上升或下降沿，右边的是错误的,

reg [ASK_WIDTH-1:0] peak_reg;  //缓存一级极值
wire [ASK_WIDTH-1:0] threshold_peak_p;  //正数
assign threshold_peak_p = threshold_peak[ASK_WIDTH-1] ? (~threshold_peak + 1'b1) : (threshold_peak);

always @(posedge clk_i, negedge rst_n)
begin
	if(~rst_n)
		begin
		WAVE_JUDGE <= 4'd1;
		cnt_point <= 12'h0;
		flag_edg_suc <= 1'b0;
		flag_edg_err <= 1'b0;
		edg_err_valid <= 1'b0;
		peak_reg <= {ASK_WIDTH{1'b0}};
		end
	else
		begin
		case(WAVE_JUDGE)
		4'd1,4'd2 :	
			begin
			if(flag_edg)
				begin
				WAVE_JUDGE <= WAVE_JUDGE + 1'b1;
				end
			end
		4'd3 :	
			begin
			case(state_edg)
			2'b00,2'b11 :
				begin
				if(flag_edg)
					begin
					flag_edg_err <= 1'b1;
					edg_err_valid <= state_edg[0];
					end
				else
					begin
					cnt_point[10:0] <= 11'h3;
					
					if(peak_reg < threshold_peak_p)
						peak_reg <= threshold_peak_p;
					
					flag_edg_err <= 1'b0;
					WAVE_JUDGE <= 4'd4;
					end
				end
			2'b01 :
				begin
				if(flag_edg)
					begin
					peak_reg <= threshold_peak_p;
					flag_edg_suc <= 1'b1;
					end
				else	
					begin
					cnt_point <= 12'h803; 
					
					flag_edg_suc <= 1'b0;
					WAVE_JUDGE <= 4'd4;
					end
				end
			2'b10 :
				begin
				if(flag_edg)
					begin
					peak_reg <= threshold_peak_p;
					flag_edg_suc <= 1'b1;
					end
				else	
					begin
					cnt_point <= 12'h003; 
					
					flag_edg_suc <= 1'b0;
					WAVE_JUDGE <= 4'd4;
					end
				end
			default:;
			endcase
			end
		4'd4 :	
			begin
			if(flag_edg_rise | flag_edg_fall)
				begin
				WAVE_JUDGE <= 4'd3;
				end
			else
				begin
				cnt_point[10:0] <= cnt_point[10:0] + 1'b1;
				end
			end
		default:;
		endcase
		end
end


/************************************************************/
//点数缓存和统计
reg [11:0] cnt_point_reg[2:0];
reg [11:0] cnt_point_err;  //连续两个相同边沿时点数缓存
reg flag_edg_valid;  //当前边沿有效
wire [11:0] point_err_max;

assign point_err_max = ((cnt_point_ptr << 1) - (cnt_point_ptr >> 1));

always @(posedge clk_i, negedge rst_n)
begin
	if(~rst_n)
		begin
		cnt_point_reg[1] <= 12'h0;
		cnt_point_reg[0] <= 12'h0;
		cnt_point_err <= 12'h0;
		flag_edg_valid <= 1'b0;
		end
	else
		begin
		if(flag_edg_suc)
			begin
			cnt_point_reg[1] <= cnt_point_err[10:0] + cnt_point;
			cnt_point_reg[0] <= cnt_point_reg[1];
			cnt_point_err <= 12'd0;
			flag_edg_valid <= 1'b1;
			end
		else if(flag_edg_err)
			begin
			if(cnt_point[10:0] > point_err_max[10:0])
				begin
				cnt_point_reg[1] <= cnt_point_err[10:0] + {edg_err_valid,cnt_point[10:0]};
				cnt_point_reg[0] <= cnt_point_reg[1];
				cnt_point_err <= 12'd0;
				flag_edg_valid <= 1'b1;
				end
			else
				begin
				if(threshold_peak_p >= peak_reg)
					begin
					cnt_point_reg[1][10:0] <= cnt_point_reg[1][10:0] + cnt_point_err[10:0] + cnt_point[10:0];
					cnt_point_err <= 12'h0;
					end
				else
					begin
					cnt_point_err[10:0] <= cnt_point_err[10:0] + cnt_point[10:0];
					end
				end
			end
		else
			begin
			flag_edg_valid <= 1'b0;
			end
		end
end



/*****************************************************************/
//输出结果
//assign pulse_point_o = {1'b0,cnt_point_reg[0][10:0]};
assign pulse_point_o = cnt_point_reg[0];
assign edge_valid = flag_edg_valid && (cnt_point_reg[0]);
assign edge_bit = cnt_point_reg[0][11];

endmodule
