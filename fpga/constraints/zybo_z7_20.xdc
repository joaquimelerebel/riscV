set_property PACKAGE_PIN K17 [get_ports clk_sys]
set_property IOSTANDARD LVCMOS33 [get_ports clk_sys]

## Buttons
set_property -dict {PACKAGE_PIN Y16 IOSTANDARD LVCMOS33} [get_ports cpu_reset]

## To use FTDI FT2232 JTAG
set_property -dict {PACKAGE_PIN V13 IOSTANDARD LVCMOS33} [get_ports trst_n]
set_property -dict {PACKAGE_PIN H15 IOSTANDARD LVCMOS33} [get_ports tck]
set_property -dict {PACKAGE_PIN W16 IOSTANDARD LVCMOS33} [get_ports tdi]
set_property -dict {PACKAGE_PIN J15 IOSTANDARD LVCMOS33} [get_ports tdo]
set_property -dict {PACKAGE_PIN V12 IOSTANDARD LVCMOS33} [get_ports tms]

## UART
set_property -dict {PACKAGE_PIN W8 IOSTANDARD LVCMOS33} [get_ports tx]
set_property -dict {PACKAGE_PIN U7 IOSTANDARD LVCMOS33} [get_ports rx]


set_property -dict { PACKAGE_PIN M14   IOSTANDARD LVCMOS33 } [get_ports { leds[0] }]; #IO_L23P_T3_35 Sch=led[0]
set_property -dict { PACKAGE_PIN M15   IOSTANDARD LVCMOS33 } [get_ports { leds[1] }]; #IO_L23N_T3_35 Sch=led[1]
set_property -dict { PACKAGE_PIN G14   IOSTANDARD LVCMOS33 } [get_ports { leds[2] }]; #IO_0_35 Sch=led[2]
set_property -dict { PACKAGE_PIN D18   IOSTANDARD LVCMOS33 } [get_ports { leds[3] }]; #IO_L3N_T0_DQS_AD1N_35 Sch=led[3]

## JTAG
# minimize routing delay

set_max_delay -to [get_ports tdo] 20.000
set_max_delay -from [get_ports tms] 20.000
set_max_delay -from [get_ports tdi] 20.000
set_max_delay -from [get_ports trst_n] 20.000

# reset signal
set_false_path -from [get_ports trst_n]


