#!/usr/bin/env python3

import re
import subprocess as sub
import time
from numpy import linspace
#import pandas as pd
from multiprocessing import Process, Pipe
import signal
import serial
import os, sys


# will output data in the csl 
VERBOSE=True
# will try to connect to the board and flash the different test to it 
# otherwise, will test in qemu
BOARD_TEST=True

GDB_CACHE="/workdir/gdbcache"

ATTACK_FILEPATH="/workdir/ripe/src/ripe_attack_generator.c"
ATTACK_MODIFIED_FILEPATH="/workdir/ripe_modified/src/ripe_attack_generator.c"

PERF_FILEPATH="/workdir/perf_baseline/"

RIPE_FILEPATH="/workdir/ripe"
RIPE_FILEPATH_MOD="/workdir/ripe_modified"


if BOARD_TEST :
	BOARD="cv32a6_zybo" 
else :
	BOARD="qemu_riscv32" 

# time to wait before force closing the core (in sec)
TIME_WAIT_GDB=10

# different options available possible for the tests
# comment the ones you don't want to test
techniques=["DIRECT", "INDIRECT"]
inject_params=["INJECTED_CODE_NO_NOP", "DATA_ONLY", "RETURN_INTO_LIBC", "RETURN_ORIENTED_PROGRAMMING"]
code_ptrs=["RET_ADDR", "FUNC_PTR_STACK_VAR", "VAR_LEAK", "LONGJMP_BUF_HEAP", "STRUCT_FUNC_PTR_HEAP"]
locations=["STACK", "HEAP"]
functions=["MEMCPY", "SPRINTF", "HOMEBREW"]


options=["technique", "inject_param", "code_ptr", "location", "function"]



if len(sys.argv) > 0 : 
	CHOSEN_ATTACK = [int(sys.argv[1])]
else : 
	CHOSEN_ATTACK = linspace(1, 10, 10, dtype=int)
	

SERIAL_FILE="/dev/ttyUSB1"

if len(sys.argv) > 1 :
	SERIAL_FILE=sys.argv[2]

GCC_MOD = 0
if len(sys.argv) > 2 :
	GCC_MOD=int(sys.argv[3])


class Attack() :
	def __init__(self, t, i, c, l, f, att_filepath, ripe_file_path,  classic=False, perf=False) :
		self.technique = t
		self.inject_param = i
		self.code_ptr = c
		self.location = l
		self.function = f
		self.arr = [t, i, c, l, f]
		self.att_filepath = att_filepath
		self.ripe_file_path = ripe_file_path
		self.classic = classic
		self.perf = perf

	#setup technique
	def setup(self, nb) : 
		if self.classic : 
			if VERBOSE :
				print(f"sudo sed -i -E 's/^(#define ATTACK_NR   [0-9]*)$/#define ATTACK_NR   {nb}/g' {self.att_filepath}")
				p=sub.Popen(f"sudo sed -i -E 's/^(#define ATTACK_NR   [0-9]*)$/#define ATTACK_NR   {nb}/g' {self.att_filepath}", shell=True)
			else : 
				p=sub.Popen(f"sudo sed -i -E 's/^(#define ATTACK_NR   [0-9]*)$/#define ATTACK_NR   {nb}/g' {self.att_filepath}", shell=True, stdout=sub.DEVNULL)
			p.communicate()

		else : 
			m = 0
			for string in self.arr : 
				if VERBOSE :
					print(f"\n-------\nsudo sed -i -E 's/(    attack.{options[m]} = [A-Z_]*;)/    attack.{options[m]} = {string};/g' {self.att_filepath}\n--------\nc")	
					p=sub.Popen(f"sudo sed -i -E 's/(    attack.{options[m]} = [A-Z_]*;)/    attack.{options[m]} = {string};/g' {self.att_filepath}", shell=True)
				else :
					p=sub.Popen(f"sudo sed -i -E 's/(    attack.{options[m]} = [A-Z_]*;)/    attack.{options[m]} = {string};/g' {self.att_filepath}", shell=True, stdout=sub.DEVNULL)
				p.communicate()
				m+=1

	# build for qemu or the board
	def build(self) :
		if GCC_MOD :	
			if VERBOSE :
				print(f"\n--------------\nsudo sh install.sh\n-------------------------\n")
				p=sub.Popen(f"sudo sh install.sh", shell=True)
			else :	
				p=sub.Popen(f"sudo sh install.sh", shell=True, stdout=sub.DEVNULL)
			p.communicate()

		if VERBOSE :
			print(f"\n--------------\nsudo west build -p -b {BOARD} {self.ripe_file_path}\n-------------------------\n")
			p=sub.Popen(f"sudo west build -p -b {BOARD} {self.ripe_file_path}", shell=True, stdout=sub.DEVNULL)
		else : 
			p=sub.Popen(f"sudo west build -p -b {BOARD} {self.ripe_file_path}", shell=True, stdout=sub.DEVNULL)
		p.communicate()


	def run(self):
		if BOARD_TEST :
			# create the gdb input file
			p=sub.Popen(f"echo 'c\nc\nq\n' > {GDB_CACHE}", shell=True)
			p.communicate()
			
			
			if VERBOSE :
				print(f"\n-----------------------\nsudo west debug\n-------------------\n")
				p=sub.Popen(f"sudo west debug < {GDB_CACHE}", shell=True)
			else : 
				p=sub.Popen(f"sudo west debug < {GDB_CACHE}", shell=True, stdout=sub.DEVNULL)
			
			time.sleep(TIME_WAIT_GDB)
			p.kill()
			#p2.kill()
			

			
			#clean gdb/cu behind
			if VERBOSE :
				print(f"\n-----------------------\nsudo pkill gdb\n-------------------\n")
				p3=sub.Popen(f"sudo pkill gdb", shell=True)
				print(f"\n-----------------------\nkill serial process\n-------------------\n")
				# p4=sub.Popen(f"sudo pkill cu", shell=True)
			else :
				p3=sub.Popen(f"sudo pkill gdb", shell=True, stdout=sub.DEVNULL)
				# p4=sub.Popen(f"sudo pkill cu",  shell=True, stdout=sub.DEVNULL)
			
			
		else :
			if VERBOSE :
				print(f"\n-----------------------\nsudo west build -t run\n-------------------\n")
				p=sub.Popen(f"sudo west build -t run &> {CACHE_FILE}", shell=True)
			else : 
				p=sub.Popen(f"sudo west build -t run &> {CACHE_FILE}", shell=True, stdout=sub.DEVNULL)
				

			time.sleep(TIME_WAIT)
			p.kill()
				
			#clean qemu behind
			if VERBOSE :
				print(f"\n-----------------------\nsudo pkill qemu\n-------------------\n")
				p=sub.Popen(f"sudo pkill qemu", shell=True)
			else :
				p=sub.Popen(f"sudo pkill qemu", shell=True, stdout=sub.DEVNULL)
			p.communicate()
		
		
						

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



def classic_attack(attacks_nb = linspace(1, 10, 10, dtype=int)) : 
	scoreboard = []
	for nb in attacks_nb :
		attaque = Attack(None, None, None, None, None, ATTACK_FILEPATH, RIPE_FILEPATH, True)
		
		print(f"\n====== ATTACK SCENARIO {nb} =========\n")
				
		# setup technique 
		attaque.setup(nb)
		
		# build
		attaque.build()

		# run 
		attaque.run()
		
		nb += 1	

	
	return scoreboard

def quality_test() : 
	attaque = Attack(None, None, None, None, None, PERF_FILEPATH, PERF_FILEPATH, False, True)

	print(f"\n====== CHECK PERFORMANCE =========\n")
							
	# build
	attaque.build()

	# run 
	result=attaque.run()
		
	new_node = attaque.to_dict()
			
	new_node["result"] = True
			
	new_node["output"] = result


	return [new_node]



if CHOSEN_ATTACK[0] <= 10 :
	classic_attack(CHOSEN_ATTACK)
else : 
	scoreboard=quality_test()


