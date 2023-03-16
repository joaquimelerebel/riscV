#!/usr/bin/env python3

import re
import subprocess as sub
import time
from numpy import linspace
from multiprocessing import Process, Pipe
import signal
import serial
import os, sys
import unicodedata, itertools


CHOSEN_ATTACK = linspace(1, 10, 10, dtype=int)
#CHOSEN_ATTACK = [4]
TIME_WAIT_GDB=15
TIME_WAIT_NEXT_STEP=4


EXCEL_OK_ATTACKS="excel_output"

GCC_MOD = 1

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


BAUD_RATE=115200
CACHE_FILE="serial_cache.dump"


def setup_serial():
	p2=sub.Popen(f"cu -l {SERIAL_PATH} -s {BAUD_RATE} > {CACHE_FILE}", shell=True)

def read_serial():
	p2=sub.Popen(f"sudo killall cu", shell=True)
	with open(CACHE_FILE, "rb") as f : 
		result=f.read()
	print(result)
	return result 

def attack_classique():
	results = []
	for att in CHOSEN_ATTACK:
		c_node={}
		
		setup_serial()

		# run 
		print(f"\n-----------------------\nsudo docker run -ti --privileged -v /dev:/dev -v `realpath workspace`:/workdir zephyr-build:v1 /bin/bash -c 'cd /workdir; sudo python script.py {att} {SERIAL_PATH} {GCC_MOD}\n-------------------\n")
		p=sub.Popen(f"sudo docker run -ti --privileged -v /dev:/dev -v `realpath workspace`:/workdir zephyr-build:v1 /bin/bash -c 'cd /workdir; sudo python script.py {att} {SERIAL_PATH} {GCC_MOD}'", shell=True)

		# p.stdin.write(b"cd workdir\nsudo ./script.py\n")

		time.sleep(TIME_WAIT_GDB)

		content = read_serial()

		c_node["output"] = content.decode("utf-8", errors='replace')

		if b"function reached." in content or b"Secret data leaked" in content or b"" == content or not b"RIPE is alive!" in content:
			c_node["result"] = False
		else :
			c_node["result"] = True

		p=sub.Popen(f"sudo docker kill $(sudo docker ps -q)", shell=True)

		results.append(c_node)
		time.sleep(TIME_WAIT_NEXT_STEP)
	return results


def display_attack_scoreboard(scoreboard, attack_nb=linspace(1, 10, 10, dtype=int)) :
	# os.system('clear')
	print("\n\n\n==============\nATTACK SCOREBOARD\n==============\n\n\n")
		
	for i in range(0,len(attack_nb)) :
		if i <= 10:
			print(attacks_array[attack_nb[i]-1].replace(";", "\n"))

		if not scoreboard[i]["result"] :
			print("\U0000274C" + f" attack {attack_nb[i]} not prevented\n\n".upper())
		else : 
			print("\U00002705" + f" attack {attack_nb[i]} prevented\n\n".upper())

		
		result=scoreboard[i]["output"].replace("b\"", "").replace("\\n", "\n")
		print(result)
	# scoreboard_pd = pd.DataFrame(scoreboard)
	# scoreboard_pd.to_excel(EXCEL_OK_ATTACKS)


# detect the right serial port 
import serial.tools.list_ports
ports = serial.tools.list_ports.comports()

SERIAL_PATH = -1;
for port, desc, hwid in sorted(ports):
		if "FT232R USB UART" in desc : 
			print(f"chosen UART USB PORT : {port}")
			SERIAL_PATH = port
			break
if SERIAL_PATH == -1 : 
	print("you did not connect the devices right")
	exit(0)


results=attack_classique()
display_attack_scoreboard(results, CHOSEN_ATTACK)
