//created by zhouhang 20170227
//FM0解码模块
//v1.0.0227

module FM0_Decoder(
	clk_i,
	rst_n_i,
	
	bit_valid_i,
	bit_data_i,
	
	wave_type_o,
	err_form_o,
	form_sync_o,
	boot_sync_o,
	
	bit_even_o,
	
	form_valid_o,
	form_data_o
);
//parameter SET_BOOT_PDG = 10'b01_1010_1000;
//parameter SET_BOOT_NDG = 10'b10_0101_0111;

parameter SET_BOOT_PDG = 8'b1010_1000;
parameter SET_BOOT_NDG = 8'b0101_0111;

input wire clk_i;
input wire rst_n_i;

input wire bit_valid_i;
input wire bit_data_i;

output reg wave_type_o;
output reg err_form_o;
output wire form_sync_o;
output wire boot_sync_o;

output wire bit_even_o;

output reg form_valid_o;
output reg form_data_o;

reg [9:0] shift_bits;
wire [9:0] boot_check;
wire [1:0] current_status;
wire [1:0] last_status;

reg flag_boot_lock;
reg flag_right_change;
reg [1:0] cnt_bits;

wire check_valid;	
reg delay_check_valid;
wire pdg_check_valid;
wire ndg_check_valid;

assign current_status = shift_bits[1:0];
assign last_status = shift_bits[3:2];
assign boot_check = shift_bits;
always@(posedge clk_i,negedge rst_n_i)
	begin
	if(!rst_n_i)
		begin
		shift_bits <= 10'd0;
		delay_check_valid <= 1'b0;
		end
	else
		begin
		delay_check_valid <= check_valid;
		if(bit_valid_i)
			shift_bits <= {shift_bits[8:0],bit_data_i};
		end
	end
assign pdg_check_valid = check_valid & (~delay_check_valid);
assign ndg_check_valid = (~check_valid) & delay_check_valid;

//切换状态检查	
always@(current_status,last_status,flag_boot_lock)
	begin
	case({last_status,current_status})
	4'b1010,4'b0101,4'b1011,4'b0100,
	4'b1101,4'b0010,4'b1100,4'b0011:
		begin
		flag_right_change = 1'b1;
		end
	default:
		begin
		flag_right_change = 1'b0;
		end
	endcase
	end

assign check_valid = (cnt_bits == 2'd1);
assign boot_sync_o = flag_boot_lock;
assign form_sync_o = flag_boot_lock;
assign bit_even_o = (flag_boot_lock & (cnt_bits[0] == 1'b0));
always@(posedge clk_i,negedge rst_n_i)
	begin
	if(!rst_n_i)
		begin
		flag_boot_lock <= 1'b0;
		wave_type_o <= 1'b0;
		cnt_bits <= 2'd0;
		err_form_o <= 1'b0;
		form_valid_o <= 1'b0;
		form_data_o <= 1'b0;
		end
	else
		begin
		if(flag_boot_lock)
			begin
			if(check_valid & (~flag_right_change))
				begin
				err_form_o <= 1'b1;
				end
				
			if(ndg_check_valid)
				begin
				form_valid_o <= 1'b1;
				case(current_status)
				2'b00,2'b11:
					form_data_o <= 1'b1;
				2'b10,2'b01:
					form_data_o <= 1'b0;
				endcase
				end
			else
				begin
				form_valid_o <= 1'b0;
				end
				
			if(bit_valid_i)
				begin
				if(cnt_bits < 2'd1)
					begin
					cnt_bits <= cnt_bits + 2'd1;
					end
				else
					begin
					cnt_bits <= 2'd0;
					end
				end
			end
		else
			begin
			cnt_bits <= 2'd0;
			if(boot_check == SET_BOOT_PDG)
				begin
				wave_type_o <= 1'b0;
				flag_boot_lock <= 1'b1;
				end
			else if(boot_check == SET_BOOT_NDG)
				begin
				wave_type_o <= 1'b1;
				flag_boot_lock <= 1'b1;
				end
			end
		end
	end

endmodule

