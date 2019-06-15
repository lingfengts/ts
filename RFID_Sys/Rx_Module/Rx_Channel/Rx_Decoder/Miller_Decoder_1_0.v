//created by zhouhang 20170213
//米勒解码模块
//v1.0.0213

module Miller_Decoder(
	clk_i,
	rst_n_i,
	
	set_mode_i,
	
	bit_valid_i,
	bit_data_i,
	
	
	err_form_o,
	err_lost_o,
	
	form_negedge_o,
	form_valid_o,
	form_data_o
);
input wire clk_i;
input wire rst_n_i;

input wire [1:0] set_mode_i;

input wire bit_valid_i;
input wire bit_data_i;

output reg err_form_o;
output reg err_lost_o;

output reg form_negedge_o;
output reg form_valid_o;
output reg form_data_o;

reg flag_form_lock;

reg [31:0] shift_bits;

always@(posedge clk_i,negedge rst_n_i)
	begin
	if(!rst_n_i)
		begin
		shift_bits <= 32'd0;
		end
	else
		begin
		if(bit_valid_i)
			begin
			shift_bits <= {shift_bits[30:0],bit_data_i};
			end
		end
	end

reg [1:0] status_form;	
reg flag_has_form;
reg flag_find_boot;
reg flag_negedge;
reg [4:0] cnt_bits_max;
always@(set_mode_i,shift_bits)
	begin
	case(set_mode_i)
	2'b00:
		begin
		cnt_bits_max = 5'd0;
		status_form = 2'd0;
		flag_has_form = 1'b0;
		flag_find_boot = 1'b0;
		flag_negedge = 1'b0;
		end
	2'b01:	//miller 2
		begin
		cnt_bits_max = 5'd4;
		case(shift_bits[7:0])
		8'hA5:
			begin
			flag_find_boot = 1'b1;
			flag_negedge = 1'b0;
			end
		8'h5A:
			begin
			flag_find_boot = 1'b1;
			flag_negedge = 1'b1;
			end
		default:
			begin
			flag_find_boot = 1'b0;
			flag_negedge = 1'b0;
			end
		endcase

		case(shift_bits[3:0])
		4'b1010:
			begin
			status_form = 2'b00;
			flag_has_form = 1'b1;
			end
		4'b0101:
			begin
			status_form = 2'b10;
			flag_has_form = 1'b1;
			end
		4'b1001:
			begin
			status_form = 2'b01;
			flag_has_form = 1'b1;
			end
		4'b0110:
			begin
			status_form = 2'b11;
			flag_has_form = 1'b1;
			end
		default:
			begin
			status_form = 2'd0;
			flag_has_form = 1'b0;
			end
		endcase
		end
	2'b10:	//miller 4
		begin
		cnt_bits_max = 5'd8;
		case(shift_bits[15:0])
		16'hAA55:
			begin
			flag_find_boot = 1'b1;
			flag_negedge = 1'b0;
			end
		16'h55AA:
			begin
			flag_find_boot = 1'b1;
			flag_negedge = 1'b1;
			end
		default:
			begin
			flag_find_boot = 1'b0;
			flag_negedge = 1'b0;
			end
		endcase
		
		case(shift_bits[7:0])
		8'b1010_1010:
			begin
			status_form = 2'b00;
			flag_has_form = 1'b1;
			end
		8'b0101_0101:
			begin
			status_form = 2'b10;
			flag_has_form = 1'b1;
			end
		8'b1010_0101:
			begin
			status_form = 2'b01;
			flag_has_form = 1'b1;
			end
		8'b0101_1010:
			begin
			status_form = 2'b11;
			flag_has_form = 1'b1;
			end
		default:
			begin
			status_form = 2'd0;
			flag_has_form = 1'b0;
			end
		endcase
		end
	2'b11:	//miller_8
		begin
		cnt_bits_max = 5'd16;
		if(shift_bits == 32'hAAAA5555)
			begin
			flag_find_boot = 1'b1;
			flag_negedge = 1'b0;
			end
		else if(shift_bits == 32'h5555AAAA)
			begin
			flag_find_boot = 1'b1;
			flag_negedge = 1'b1;
			end
		else
			begin
			flag_find_boot = 1'b0;
			flag_negedge = 1'b0;
			end
		
		case(shift_bits[15:0])
		16'b10101010_10101010:
			begin
			status_form = 2'b00;
			flag_has_form = 1'b1;
			end
		16'b01010101_01010101:
			begin
			status_form = 2'b10;
			flag_has_form = 1'b1;
			end
		16'b10101010_01010101:
			begin
			status_form = 2'b01;
			flag_has_form = 1'b1;
			end
		16'b01010101_10101010:
			begin
			status_form = 2'b11;
			flag_has_form = 1'b1;
			end
		default:
			begin
			status_form = 2'd0;
			flag_has_form = 1'b0;
			end
		endcase
		end
	endcase
	end

reg [4:0] cnt_bits;	
reg [1:0] last_status_form;
always@(posedge clk_i,negedge rst_n_i)
	begin
	if(!rst_n_i)
		begin
		flag_form_lock <= 1'b0;
		form_negedge_o <= 1'b0;
		cnt_bits <= 4'd0;
		last_status_form <= 2'd0;
		err_form_o <= 1'b0;
		err_lost_o <= 1'b0;
		form_valid_o <= 1'b0;
		form_data_o <= 1'b0;
		end
	else
		begin
		if(flag_form_lock)
			begin
			if(bit_valid_i)
				begin
				cnt_bits <= cnt_bits + 4'd1;
				end
			else
				begin
				if(cnt_bits == cnt_bits_max)
					begin
					cnt_bits <= 4'd0;
					if(flag_has_form)
						begin
						last_status_form <= status_form;
						case({last_status_form,status_form})
						4'h0,4'h3,4'h4,4'h5,4'h9,4'hA,4'hE,4'hF:
							begin
							err_form_o <= 1'b1;
							form_valid_o <= 1'b1;
							form_data_o <= 1'b0;
							end
						default:
							begin
							form_valid_o <= 1'b1;
							form_data_o <= status_form[0];
							end
						endcase
						end
					else
						begin
						err_lost_o <= 1'b1;
						end
					end
				else
					begin
					form_valid_o <= 1'b0;
					form_data_o <= 1'b0;
					end
				end
			end
		else
			begin
			if(flag_find_boot)
				begin
				flag_form_lock <= 1'b1;
				form_negedge_o <= flag_negedge;
				last_status_form <= status_form;
				end
			end
		end
	end

endmodule
 