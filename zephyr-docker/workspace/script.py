#!/usr/bin/env python3

import re
import subprocess as sub
import time
from numpy import linspace


# premiere version faite pour docker 
# à ameliorer une fois qu'on a un uart 
# pour simplifier le scoreboard sur la carte 

CHOSEN_ATTACK = linspace(1, 10, 10, dtype=int)
#CHOSEN_ATTACK = [4]

ATTACK_FILEPATH="/workdir/ripe/src/ripe_attack_generator.c"
CACHE_FILE="/workdir/cache_output_file"
RIPE_FILEPATH="/workdir/ripe"
APP_FILEPATH=["/workdir/zephyr/samples/hello_world"]
BOARD="qemu_riscv32" # "cv32a6_zybo"

# time to wait before force closing the core (in sec)
TIME_WAIT=3

attacks_array = ["technique = DIRECT;inject_param = INJECTED_CODE_NO_NOP;code_ptr= RET_ADDR;location = STACK;function = MEMCPY;",
				"technique = DIRECT;inject_param = INJECTED_CODE_NO_NOP;code_ptr= FUNC_PTR_STACK_VAR;location = STACK;function = MEMCPY;",
				"technique = INDIRECT;inject_param = INJECTED_CODE_NO_NOP;code_ptr= FUNC_PTR_STACK_VAR;location = STACK;function = MEMCPY;",	
				"technique = DIRECT;inject_param = DATA_ONLY;code_ptr= VAR_LEAK;location = HEAP;function = SPRINTF;",
				"technique = DIRECT;inject_param = RETURN_INTO_LIBC;code_ptr= RET_ADDR;location = STACK;function = MEMCPY;",
				"technique = INDIRECT;inject_param = RETURN_INTO_LIBC;code_ptr= FUNC_PTR_HEAP;location = HEAP;function = MEMCPY;",
				"technique = INDIRECT;inject_param = RETURN_INTO_LIBC;code_ptr= STRUCT_FUNC_PTR_HEAP;location = HEAP;function = HOMEBREW;",
				"technique = INDIRECT;inject_param = RETURN_INTO_LIBC;code_ptr= LONGJMP_BUF_HEAP;location = HEAP;function = MEMCPY;",
				"technique = DIRECT;inject_param = RETURN_ORIENTED_PROGRAMMING;code_ptr= RET_ADDR;location = STACK;function = MEMCPY;",
				"technique = DIRECT;inject_param = RETURN_ORIENTED_PROGRAMMING;code_ptr= STRUCT_FUNC_PTR_HEAP;location = HEAP;function = SPRINTF;"]

def classic_app() :
	scoreboard = []
	for app in APP_FILEPATH :
		print(f"\n====== APP SCENARIO {app} =========\n")
		# build
		print(f"--------------\n\n\nsudo west build -p -b {BOARD} {app}\n\n\n -------------------------")
		p=sub.Popen(f"sudo west build -p -b {BOARD} {app}", shell=True)
		p.communicate()

		# run 
		print(f"\n-----------------------\nsudo west build -t run\n-------------------\n")
		p=sub.Popen(f"sudo west build -t run > {CACHE_FILE}", shell=True)
		time.sleep(TIME_WAIT)
		p.kill()
		with open(CACHE_FILE, "rb") as f : 
			result=f.read()
		print(result)
		if b"function reached." in result :
			scoreboard.append(True)
		else :
			scoreboard.append(False)
	return scoreboard

def attack(attacks_nb = linspace(1, 10, 10, dtype=int)) : 
	scoreboard = []
	for nb in attacks_nb :
		print(f"\n====== ATTACK SCENARIO {nb} =========\n")
		p=sub.Popen(f"sudo sed -i -E 's/^(#define ATTACK_NR   [0-9]*)$/#define ATTACK_NR   {nb}/g' {ATTACK_FILEPATH}", shell=True)
		p.communicate()
		# build
		print(f"--------------\n\n\nsudo west build -p -b {BOARD} {RIPE_FILEPATH}\n\n\n -------------------------")
		p=sub.Popen(f"sudo west build -p -b {BOARD} {RIPE_FILEPATH}", shell=True)
		p.communicate()


		# run 
		print(f"\n-----------------------\nsudo west build -t run\n-------------------\n")
		p=sub.Popen(f"sudo west build -t run > {CACHE_FILE}", shell=True)
		time.sleep(TIME_WAIT)
		p.kill()
		with open(CACHE_FILE, "rb") as f : 
			result=f.read()
		
		if b"function reached." in result or b"Secret data leaked" in result :
			scoreboard.append(True)
		else :
			scoreboard.append(False)

		try :
			result = result.decode("utf-8")
		except Exception :
			print("NOT PRINTABLE")
		finally : 
			print(result)

	return scoreboard


def display_attack_scoreboard(scoreboard, attack_nb=linspace(1, 10, 10, dtype=int)) :
	print("\n\n\n==============\nATTACK SCOREBOARD\n==============\n\n\n")
	for i in range(0,len(attack_nb)) :
		print(attacks_array[attack_nb[i]-1].replace(";", "\n"))
		if scoreboard[i] :
			print("\U0000274C" + f" attack {attack_nb[i]} not prevented\n\n".upper())
		else : 
			print("\U00002705" + f" attack {attack_nb[i]} prevented\n\n".upper())





scoreboard = attack(CHOSEN_ATTACK)
display_attack_scoreboard(scoreboard, CHOSEN_ATTACK)


