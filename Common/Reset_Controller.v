//created by zhouhang 20151120
//Reset controller module
//使用异步复位~同步释放模式，包含有上电自动复位功能

// altera message_off 10230
module Reset_Controller(
	clk_i,
	arst_n_i,
	pll_lock_i,

	srst_n_o,
	srst_o
);
parameter COUNT_UNIT_NS = 20'd10;	/*时间间隔参数，即驱动模块时钟周期，单位为ns*/
parameter SETUP_US = 10;				/*复位信号保持时间*/

input wire clk_i;
input wire arst_n_i;						/*异步或同步复位信号引入*/

input wire pll_lock_i;
output wire srst_n_o;					/*同步复位信号输出，低电平有效*/
output wire srst_o;						/*同步复位信号输出，高电平有效*/

reg [31:0] cnt_us;
reg [19:0] cnt_ns;
reg setup_rst;
wire sync_reset_source;
reg flag_reset;
reg [1:0] delay_flag_reset;

assign sync_reset_source = delay_flag_reset[1] & setup_rst;	/*复位信号源*/
assign srst_n_o = (sync_reset_source);
assign srst_o = ~(sync_reset_source);
always@(posedge clk_i,negedge arst_n_i)
	begin
	if(!arst_n_i)
		begin
		flag_reset <= 1'b0;
		delay_flag_reset <= 2'd0;
		end
	else
		begin
		flag_reset <= 1'b1;
		delay_flag_reset <= {delay_flag_reset[0],flag_reset};	/*复位信号同步，解决异步复位信号释放时可能产生的亚稳态*/
		end
	end

//synthesis translate_off
/*just for simulation*/
/*实际上电这两个寄存器默认为0,此处是为了仿真时数值的初始化*/
initial
	begin
	cnt_ns = 0;
	cnt_us = 0;
	end

//synthesis translate_on

	
always@(posedge clk_i)
	begin
	if(cnt_us >= SETUP_US)			/*复位计时到设定值后，置位信号*/
		begin
		setup_rst <= 1'b1;
		end
	else
		begin
		setup_rst <= 1'b0;
		if(cnt_ns >= 20'd1000)		/*ns -> us 进位*/
			begin
			cnt_ns <= 20'd0;
			cnt_us <= cnt_us + 32'd1;
			end
		else
			begin
			cnt_ns <= cnt_ns + COUNT_UNIT_NS;
			end
		end
	end

endmodule
