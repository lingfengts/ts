//created by zhouhang 20170504
//抽样模块，根据反向链路速率选择不同的抽样
//v1.0.0508

module Data_Sample(
	clk_i,
	rst_n_i,
	
	set_speed_i,
	
	idata_i,
	qdata_i,
	
	valid_o,
	idata_o,
	qdata_o
);
parameter SET_INPUT_WIDTH = 23;
parameter SET_OUTPUT_WIDTH = 17;

input wire clk_i;
input wire rst_n_i;

input wire [2:0] set_speed_i;

input wire signed [SET_INPUT_WIDTH-1:0] idata_i;
input wire signed [SET_INPUT_WIDTH-1:0] qdata_i;

output reg valid_o;
output reg signed [SET_OUTPUT_WIDTH-1:0] idata_o;
output reg signed [SET_OUTPUT_WIDTH-1:0] qdata_o; 

//根据反向链路速率选择采样率
//000 64K:25M/16
//001 137K:25M/8
//010 174K:25M/4
//011 320K:25M/2
//100 128K:25M/8
//101 274K:25M/4
//110 349K:25M/2
//111 640K:25M/1

reg [3:0] sample_rate;
reg [3:0] cnt_sample;
always@(posedge clk_i,negedge rst_n_i)
	begin
	if(!rst_n_i)
		begin
		sample_rate <= 4'd0;
		end
	else
		begin
		case(set_speed_i)
		3'b000:
			sample_rate <= 4'd9;
		3'b001:
			sample_rate <= 4'd4;
		3'b010:
			sample_rate <= 4'd3;
		3'b011:
			sample_rate <= 4'd1;
		3'b100:
			sample_rate <= 4'd4;
		3'b101:
			sample_rate <= 4'd2;
		3'b110:
			sample_rate <= 4'd1;
		3'b111:
			sample_rate <= 4'd0;
		endcase
		end
	end

always@(posedge clk_i,negedge rst_n_i)
	begin
	if(!rst_n_i)
		begin
		cnt_sample <= 4'd0;
		valid_o <= 1'b0;
		idata_o <= {SET_OUTPUT_WIDTH{1'b0}};
		qdata_o <= {SET_OUTPUT_WIDTH{1'b0}};
		end
	else
		begin
		if(cnt_sample < sample_rate)
			begin
			cnt_sample <= cnt_sample + 4'd1;
			valid_o <= 1'b0;
			end
		else
			begin
			cnt_sample <= 3'd0;
			valid_o <= 1'b1;
			idata_o <= idata_i[SET_INPUT_WIDTH-1:(SET_INPUT_WIDTH-SET_OUTPUT_WIDTH)];
			qdata_o <= qdata_i[SET_INPUT_WIDTH-1:(SET_INPUT_WIDTH-SET_OUTPUT_WIDTH)];
			end
		end
	end

endmodule
