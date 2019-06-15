//created by zhouhang 
//v1.0.0405

module Arithmetic_Mult(
	clk_i,
	rst_n_i,
	
	valid_i,
	dataa_i,
	datab_i,
	
	data_o
);
parameter SET_DATAA_WIDTH = 12;
parameter SET_DATAB_WIDTH = 12;
parameter SET_OUT_WIDTH = (SET_DATAA_WIDTH + SET_DATAB_WIDTH) - 1;

input wire clk_i;
input wire rst_n_i;

input wire valid_i;
input wire signed [SET_DATAA_WIDTH-1:0] dataa_i;
input wire signed [SET_DATAB_WIDTH-1:0] datab_i;

output reg signed [SET_OUT_WIDTH-1:0] data_o;

wire signed [SET_DATAA_WIDTH-1:0] data_value;
wire signed [SET_DATAB_WIDTH-1:0] nco_value;

assign data_value = (dataa_i == {1'b1,{(SET_DATAA_WIDTH-1){1'b0}}}) ? 
							{dataa_i + 1} : dataa_i;	
assign nco_value = (datab_i == {1'b1,{(SET_DATAA_WIDTH-1){1'b0}}}) ? 
							{datab_i + 1} : datab_i;	
							

always@(posedge clk_i,negedge rst_n_i)
	begin
	if(!rst_n_i)
		begin
		data_o <= {SET_OUT_WIDTH{1'b0}};
		end
	else
		begin
		if(valid_i)
			data_o <= data_value * nco_value;
		end
	end
	
endmodule
