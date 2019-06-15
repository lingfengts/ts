// megafunction wizard: %ALTSQRT%VBB%
// GENERATION: STANDARD
// VERSION: WM1.0
// MODULE: ALTSQRT 

// ============================================================
// File Name: Sort.v
// Megafunction Name(s):
// 			ALTSQRT
//
// Simulation Library Files(s):
// 			altera_mf
// ============================================================
// ************************************************************
// THIS IS A WIZARD-GENERATED FILE. DO NOT EDIT THIS FILE!
//
// 14.1.0 Build 186 12/03/2014 SJ Full Version
// ************************************************************

//Copyright (C) 1991-2014 Altera Corporation. All rights reserved.
//Your use of Altera Corporation's design tools, logic functions 
//and other software and tools, and its AMPP partner logic 
//functions, and any output files from any of the foregoing 
//(including device programming or simulation files), and any 
//associated documentation or information are expressly subject 
//to the terms and conditions of the Altera Program License 
//Subscription Agreement, the Altera Quartus II License Agreement,
//the Altera MegaCore Function License Agreement, or other 
//applicable license agreement, including, without limitation, 
//that your use is for the sole purpose of programming logic 
//devices manufactured by Altera and sold by Altera or its 
//authorized distributors.  Please refer to the applicable 
//agreement for further details.

module Sort (
	aclr,
	clk,
	radical,
	q,
	remainder);

	input	  aclr;
	input	  clk;
	input	[23:0]  radical;
	output	[11:0]  q;
	output	[12:0]  remainder;

endmodule

// ============================================================
// CNX file retrieval info
// ============================================================
// Retrieval info: PRIVATE: INTENDED_DEVICE_FAMILY STRING "Cyclone IV GX"
// Retrieval info: PRIVATE: SYNTH_WRAPPER_GEN_POSTFIX STRING "0"
// Retrieval info: LIBRARY: altera_mf altera_mf.altera_mf_components.all
// Retrieval info: CONSTANT: PIPELINE NUMERIC "1"
// Retrieval info: CONSTANT: Q_PORT_WIDTH NUMERIC "12"
// Retrieval info: CONSTANT: R_PORT_WIDTH NUMERIC "13"
// Retrieval info: CONSTANT: WIDTH NUMERIC "24"
// Retrieval info: USED_PORT: aclr 0 0 0 0 INPUT NODEFVAL "aclr"
// Retrieval info: USED_PORT: clk 0 0 0 0 INPUT NODEFVAL "clk"
// Retrieval info: USED_PORT: q 0 0 12 0 OUTPUT NODEFVAL "q[11..0]"
// Retrieval info: USED_PORT: radical 0 0 24 0 INPUT NODEFVAL "radical[23..0]"
// Retrieval info: USED_PORT: remainder 0 0 13 0 OUTPUT NODEFVAL "remainder[12..0]"
// Retrieval info: CONNECT: @aclr 0 0 0 0 aclr 0 0 0 0
// Retrieval info: CONNECT: @clk 0 0 0 0 clk 0 0 0 0
// Retrieval info: CONNECT: @radical 0 0 24 0 radical 0 0 24 0
// Retrieval info: CONNECT: q 0 0 12 0 @q 0 0 12 0
// Retrieval info: CONNECT: remainder 0 0 13 0 @remainder 0 0 13 0
// Retrieval info: GEN_FILE: TYPE_NORMAL Sort.v TRUE
// Retrieval info: GEN_FILE: TYPE_NORMAL Sort.inc FALSE
// Retrieval info: GEN_FILE: TYPE_NORMAL Sort.cmp FALSE
// Retrieval info: GEN_FILE: TYPE_NORMAL Sort.bsf FALSE
// Retrieval info: GEN_FILE: TYPE_NORMAL Sort_inst.v TRUE
// Retrieval info: GEN_FILE: TYPE_NORMAL Sort_bb.v TRUE
// Retrieval info: LIB_FILE: altera_mf
