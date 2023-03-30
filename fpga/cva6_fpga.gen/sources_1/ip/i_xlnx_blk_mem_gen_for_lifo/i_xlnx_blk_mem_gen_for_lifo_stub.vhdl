-- Copyright 1986-2020 Xilinx, Inc. All Rights Reserved.
-- --------------------------------------------------------------------------------
-- Tool Version: Vivado v.2020.2 (lin64) Build 3064766 Wed Nov 18 09:12:47 MST 2020
-- Date        : Thu Mar 30 09:51:30 2023
-- Host        : debian running 64-bit Debian GNU/Linux bookworm/sid
-- Command     : write_vhdl -force -mode synth_stub
--               /home/ulysse/Documents/CENTRALE/RISCV_proj/riscV_v2/fpga/cva6_fpga.gen/sources_1/ip/i_xlnx_blk_mem_gen_for_lifo/i_xlnx_blk_mem_gen_for_lifo_stub.vhdl
-- Design      : i_xlnx_blk_mem_gen_for_lifo
-- Purpose     : Stub declaration of top-level module interface
-- Device      : xc7z020clg400-1
-- --------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity i_xlnx_blk_mem_gen_for_lifo is
  Port ( 
    clka : in STD_LOGIC;
    wea : in STD_LOGIC_VECTOR ( 0 to 0 );
    addra : in STD_LOGIC_VECTOR ( 12 downto 0 );
    dina : in STD_LOGIC_VECTOR ( 31 downto 0 );
    clkb : in STD_LOGIC;
    addrb : in STD_LOGIC_VECTOR ( 12 downto 0 );
    doutb : out STD_LOGIC_VECTOR ( 31 downto 0 )
  );

end i_xlnx_blk_mem_gen_for_lifo;

architecture stub of i_xlnx_blk_mem_gen_for_lifo is
attribute syn_black_box : boolean;
attribute black_box_pad_pin : string;
attribute syn_black_box of stub : architecture is true;
attribute black_box_pad_pin of stub : architecture is "clka,wea[0:0],addra[12:0],dina[31:0],clkb,addrb[12:0],doutb[31:0]";
attribute x_core_info : string;
attribute x_core_info of stub : architecture is "blk_mem_gen_v8_4_4,Vivado 2020.2";
begin
end;
