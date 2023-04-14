<z_bss_zero>:
<@\textcolor{red}{\textbf{li}}@>	   <@\textcolor{red}{\textbf{zero},2}@>
addi	sp,sp,-16
sw	ra,12(sp)
lui	a0,0x8000b
addi	a2,a0,-336 # 8000aeb0
lui	a5,0x8000b
addi	a5,a5,980 # 8000b3d4
sub	a2,a5,a2
li	a1,0
addi	a0,a0,-336
jal	ra,800076e0 # call <z_early_memset>
<@\textcolor{red}{\textbf{li}}@>	   <@\textcolor{red}{\textbf{zero},1}@>
lw	ra,12(sp)
addi	sp,sp,16
ret