#!/usr/bin/env python

import re
import subprocess as sub
import time

ATTACK_FILEPATH="/workdir/ripe/src/ripe_attack_generator.c"
# ATTACK_FILEPATH="text"
RIPE_FILEPATH="/workdir/ripe"
BOARD="qemu_riscv32" # "cv32a6_zybo"


scordboard = 0
for nb in range(10) :
	print(f"====== ATTACK SCENARIO {nb} =========")
	p=sub.Popen(f"sudo sed -i -E 's/^(#define ATTACK_NR   [0-9])$/#define ATTACK_NR   {nb}/g' {ATTACK_FILEPATH}", shell=True)
	p.communicate()
	# build
	print(f"--------------\n\n\nsudo west build -p -b {BOARD} {RIPE_FILEPATH}\n\n\n -------------------------")
	p=sub.Popen(f"sudo west build -p -b {BOARD} {RIPE_FILEPATH}", shell=True)
	p.communicate()


	# run 
	print(f"-----------------------\nsudo west build -t run\n-------------------")
	p=sub.Popen(f"sudo west build -t run", stdout=sub.PIPE, shell=True)
	time.sleep(2)
	p.kill()
	result = p.stdout.read()
	print(result)
	if "Code injection function reached." in result :
		scordboard += 1
print(f"{scordboard=}")
