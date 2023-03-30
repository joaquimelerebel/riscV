// Copyright 1986-2020 Xilinx, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2020.2 (lin64) Build 3064766 Wed Nov 18 09:12:47 MST 2020
// Date        : Thu Mar 30 09:51:30 2023
// Host        : debian running 64-bit Debian GNU/Linux bookworm/sid
// Command     : write_verilog -force -mode synth_stub
//               /home/ulysse/Documents/CENTRALE/RISCV_proj/riscV_v2/fpga/cva6_fpga.gen/sources_1/ip/i_xlnx_blk_mem_gen_for_lifo/i_xlnx_blk_mem_gen_for_lifo_stub.v
// Design      : i_xlnx_blk_mem_gen_for_lifo
// Purpose     : Stub declaration of top-level module interface
// Device      : xc7z020clg400-1
// --------------------------------------------------------------------------------

// This empty module with port declaration file causes synthesis tools to infer a black box for IP.
// The synthesis directives are for Synopsys Synplify support to prevent IO buffer insertion.
// Please paste the declaration into a Verilog source file or add the file as an additional source.
(* x_core_info = "blk_mem_gen_v8_4_4,Vivado 2020.2" *)
module i_xlnx_blk_mem_gen_for_lifo(clka, wea, addra, dina, clkb, addrb, doutb)
/* synthesis syn_black_box black_box_pad_pin="clka,wea[0:0],addra[12:0],dina[31:0],clkb,addrb[12:0],doutb[31:0]" */;
  input clka;
  input [0:0]wea;
  input [12:0]addra;
  input [31:0]dina;
  input clkb;
  input [12:0]addrb;
  output [31:0]doutb;
endmodule
