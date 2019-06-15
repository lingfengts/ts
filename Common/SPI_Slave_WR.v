/***************************
File 		: 	SPI_Slave_WR.v
Project 	: 	RFID
Author 		: 	zhangqi
Time 		: 	20170808
Function 	: 	完成从设备SPI读写功能;
***************************/
module	SPI_Slave_WR(
		clk_i,
		rst_n,
		
		tx_data_i,
		tx_byte_done_o,
		
		rx_byte_valid_o,
		rx_data_o,
		
		spi_wr_i,
		sclk_i,
		sncs_i,
		sdata_s_o,
		sdata_s_i
		);
		
parameter	CPOL = 1'b0;	//时钟空闲状态，空闲为高电平
parameter	CPHA = 1'b0;	//时钟采数边沿，第一个边沿开始采集数据
parameter	SPI_WIDTH = 5'd8;	//SPI宽度
		
		
input wire 					clk_i;	//时钟信号，100M
input wire 					rst_n;

input wire [SPI_WIDTH-1:0]	tx_data_i;	//发送数据输入
output wire 				tx_byte_done_o;	//发送一个字节完成，通知取下一个字节数据

output wire 				rx_byte_valid_o;	//发送数据有效，触发spi开始发送
output reg [SPI_WIDTH-1:0]	rx_data_o;	//发送数据输入


input wire 					spi_wr_i;	//spi读写标志	1:读，从安全模块读取到有效数据  0：写，输出至安全模块
input wire 					sclk_i;		//spi时钟输出
input wire 					sncs_i;		//spi片选
output wire 				sdata_s_o;	//主入从出，第一个边沿采集数据
input wire 					sdata_s_i;	//主出从入


//spi时钟信号
//读写操作
wire spi_rst;
reg [4:0] cnt_tx_bit;	//spi有效位宽
reg [4:0] cnt_rx_bit;
reg [4:0] cnt_rx_bit_dly;
reg [SPI_WIDTH-1:0] tx_data_valid;	//发送有效数据

assign spi_rst = rst_n & (~sncs_dly[1]);

assign tx_byte_done_o = (~spi_wr_i) & (~sncs_dly[1]) & sclk_edge_valid & (cnt_tx_bit == (SPI_WIDTH - 1));
assign rx_byte_valid_o = spi_wr_i & (~sncs_dly[1]) & (cnt_rx_bit_dly == 5'd0) & (cnt_rx_bit == (SPI_WIDTH - 1'b1));


reg [1:0] sclk_dly;
reg [1:0] sncs_dly;
reg [1:0] sdata_si_dly;
wire pdg_sclk;
wire ndg_sclk;
wire sclk_edge_first;	//第一个边沿
wire sclk_edge_second;	//第二个边沿
wire sclk_edge_valid;

assign pdg_sclk = (~sclk_dly[1]) & sclk_dly[0];
assign ndg_sclk = sclk_dly[1] & (~sclk_dly[0]);
assign sclk_edge_first = CPOL ? ndg_sclk : pdg_sclk;
assign sclk_edge_second = CPOL ? pdg_sclk : ndg_sclk;
assign sclk_edge_valid = CPHA ? sclk_edge_second : sclk_edge_first;

always @(posedge clk_i, negedge rst_n)
begin
	if(!rst_n)
		begin
		sclk_dly <= 2'b0;
		sncs_dly <= 2'b0;
		sdata_si_dly <= 2'b0;
		cnt_rx_bit_dly <= 5'd0;
		end
	else
		begin
		sclk_dly <= {sclk_dly[0],sclk_i};
		sncs_dly <= {sncs_dly[0],sncs_i};
		sdata_si_dly <= {sdata_si_dly[0],sdata_s_i};
		cnt_rx_bit_dly <= cnt_rx_bit;
		end
end


//从设备接收 数据输入
always @(posedge clk_i, negedge spi_rst)
begin
	if(!spi_rst)
		begin
		cnt_rx_bit <= SPI_WIDTH - 1'b1;
		rx_data_o <= {SPI_WIDTH{1'b0}};
		end
	else
		begin
		if(sclk_edge_valid)
			begin
			rx_data_o[cnt_rx_bit] <= sdata_si_dly[1];
			
			if(cnt_rx_bit >= 5'd1)
				cnt_rx_bit <= cnt_rx_bit - 1'b1;
			else
				cnt_rx_bit <= SPI_WIDTH-1;
			end
		end
end


//从设备发送 数据输出至安全模块
always @(posedge clk_i, negedge spi_rst)
begin
	if(!spi_rst)
		begin
		tx_data_valid <= {SPI_WIDTH{1'b0}};
		cnt_tx_bit <= 5'd0;
		end
	else
		begin
		if((!sclk_edge_valid) && (cnt_tx_bit == 5'd0))
			tx_data_valid <= tx_data_i;
		else if(sclk_edge_valid)
			begin
			tx_data_valid <= (tx_data_i << (cnt_tx_bit + 1'b1));
			
			if(cnt_tx_bit <= (SPI_WIDTH - 2))
				begin
				cnt_tx_bit <= cnt_tx_bit + 1'b1;
				end
			else 
				begin
				cnt_tx_bit <= 5'd0;
				end
			end
		end
end

assign sdata_s_o = (~spi_wr_i) & tx_data_valid[7];

endmodule
