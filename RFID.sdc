#create by zhouhang

create_clock -name ext_clk -period 20.000 [get_ports {EXT_CLK}]

derive_pll_clocks
derive_clock_uncertainty

#set_false_path
#set_false_path -from [get_clocks {M_Main_Pll|*|clk[0]}] -to [get_clocks {M_Main_Pll|*|clk[2]}]}]
set_false_path -from [get_clocks {M_Main_Pll|altpll_component|auto_generated|pll1|clk[0]}] -to [get_clocks {M_Main_Pll|altpll_component|auto_generated|pll1|clk[2]}]
set_false_path -from [get_clocks {M_Main_Pll|altpll_component|auto_generated|pll1|clk[0]}] -to [get_clocks {M_Main_Pll|altpll_component|auto_generated|pll1|clk[1]}]
set_false_path -from [get_clocks {M_Main_Pll|altpll_component|auto_generated|pll1|clk[1]}] -to [get_clocks {M_Main_Pll|altpll_component|auto_generated|pll1|clk[0]}]
set_false_path -from [get_clocks {M_Main_Pll|altpll_component|auto_generated|pll1|clk[1]}] -to [get_clocks {M_Main_Pll|altpll_component|auto_generated|pll1|clk[2]}]
set_false_path -from [get_clocks {M_Main_Pll|altpll_component|auto_generated|pll1|clk[2]}] -to [get_clocks {M_Main_Pll|altpll_component|auto_generated|pll1|clk[1]}]
#set_false_path -from [get_clocks {M_Main_Pll|*|clk[0]}] -to [get_clocks {M_Main_Pll|*|clk[1]}]}]
#set_false_path -from [get_clocks {M_Main_Pll|*|clk[1]}] -to [get_clocks {M_Main_Pll|*|clk[0]}]}]
#set_false_path -from [get_clocks {M_Main_Pll|*|clk[1]}] -to [get_clocks {M_Main_Pll|*|clk[2]}]}]
#set_false_path -from [get_clocks {M_Main_Pll|*|clk[2]}] -to [get_clocks {M_Main_Pll|*|clk[1]}]}]
set_false_path -from {Reset_Controller:M_Reset_Controller|setup_rst} -to {*}