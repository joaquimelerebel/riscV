#!/usr/bin/env python3

import re
import subprocess as sub
import time
from numpy import linspace
import pandas as pd


# premiere version faite pour docker 
# à ameliorer une fois qu'on a un uart 
# pour simplifier le scoreboard sur la carte 

CHOSEN_ATTACK = linspace(1, 10, 10, dtype=int)
#CHOSEN_ATTACK = [4]

VERBOSE=True

ATTACK_FILEPATH="/workdir/ripe/src/ripe_attack_generator.c"
ATTACK_MODIFIED_FILEPATH="/workdir/ripe_modified/src/ripe_attack_generator.c"
CACHE_FILE="/workdir/cache_output_file"
RIPE_FILEPATH="/workdir/ripe"
RIPE_FILEPATH_MOD="/workdir/ripe_modified"
APP_FILEPATH=["/workdir/zephyr/samples/hello_world"]
BOARD="qemu_riscv32" # "cv32a6_zybo"
EXCEL_OK_ATTACKS="/workdir/are_ok_attacks.xlsx"

# time to wait before force closing the core (in sec)
TIME_WAIT=2
TIME_WAIT_FAST=1


tecniques=["DIRECT", "INDIRECT"]
inject_params=["INJECTED_CODE_NO_NOP", "DATA_ONLY", "RETURN_INTO_LIBC", "RETURN_ORIENTED_PROGRAMMING"]
# inject_params=["INJECTED_CODE_NO_NOP"]
code_ptrs=["RET_ADDR", "FUNC_PTR_STACK_VAR", "VAR_LEAK", "LONGJMP_BUF_HEAP", "STRUCT_FUNC_PTR_HEAP"]
# code_ptrs=["RET_ADDR"]
locations=["STACK", "HEAP"]
# locations=["STACK"]
functions=["MEMCPY", "SPRINTF", "HOMEBREW"]
# functions=["MEMCPY"]

options=["technique", "inject_param", "code_ptr", "location", "function"]



class Attack() :
	def __init__(self, t, i, c, l, f, att_filepath, ripe_file_path) :
		self.technique = t
		self.inject_param = i
		self.code_ptr = c
		self.location = l
		self.function = f
		self.arr = [t, i, c, l, f]
		self.att_filepath = att_filepath
		self.ripe_file_path = ripe_file_path

	def to_dict(self):
		diction = {}
		index = 0
		for opt in options : 
			diction[opt] = self.arr[index]
			index += 1
		return diction

	#setup technique
	def setup(self) : 
		m = 0
		for string in self.arr : 
			if VERBOSE :
				print(f"\n-------\nsudo sed -i -E 's/(    attack.{options[m]} = [A-Z_]*;)/    attack.{options[m]} = {string};/g' {self.att_filepath}\n--------\nc")	
				p=sub.Popen(f"sudo sed -i -E 's/(    attack.{options[m]} = [A-Z_]*;)/    attack.{options[m]} = {string};/g' {self.att_filepath}", shell=True)
			else :
				p=sub.Popen(f"sudo sed -i -E 's/(    attack.{options[m]} = [A-Z_]*;)/    attack.{options[m]} = {string};/g' {self.att_filepath}", shell=True, stdout=sub.DEVNULL)
			p.communicate()
			m+=1


	def build(self) :		
		if VERBOSE :
			print(f"\n--------------\nsudo west build -p -b {BOARD} {self.ripe_file_path}\n-------------------------\n")
			p=sub.Popen(f"sudo west build -p -b {BOARD} {self.ripe_file_path}", shell=True)
		else : 
			p=sub.Popen(f"sudo west build -p -b {BOARD} {self.ripe_file_path}", shell=True, stdout=sub.DEVNULL)
		p.communicate()

	def run(self):
		if VERBOSE :
			print(f"\n-----------------------\nsudo west build -t run\n-------------------\n")
		p=sub.Popen(f"sudo west build -t run &> {CACHE_FILE}", shell=True)
		time.sleep(TIME_WAIT_FAST)
		p.kill()
			
		#clean qemu behind
		if VERBOSE :
			print(f"\n-----------------------\nsudo pkill qemu\n-------------------\n")
			p=sub.Popen(f"sudo pkill qemu", shell=True, stdout=sub.DEVNULL)
		else :
			p=sub.Popen(f"sudo pkill qemu", shell=True)
		p.communicate()
		
		
		with open(CACHE_FILE, "rb") as f : 
			result=f.read()
		return result
						



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
		p=sub.Popen(f"sudo west build -p -b {BOARD} app", shell=True)
		p.communicate()

		# run 
		print(f"\n-----------------------\nsudo west build -t run\n-------------------\n")
		p=sub.Popen(f"sudo west build -t run &> {CACHE_FILE}", shell=True)
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

def classic_attack(attacks_nb = linspace(1, 10, 10, dtype=int)) : 
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
		p=sub.Popen(f"sudo west build -t run &> {CACHE_FILE}", shell=True)
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


def is_OK(attack) :
	if ((attack.inject_param == "INJECTED_CODE_NO_NOP") and
	  (not (attack.function == "MEMCPY") and not (attack.function == "HOMEBREW"))):
		return False;
	
	if (attack.inject_param == "RETURN_ORIENTED_PROGRAMMING" and
	  attack.technique != "DIRECT") :
		return False;

	if (attack.inject_param == "DATA_ONLY") :
		if (attack.code_ptr != "VAR_BOF" and
			attack.code_ptr != "VAR_IOF" and
			attack.code_ptr != "VAR_LEAK") : 
			return False;

		if ((attack.code_ptr == "VAR_LEAK" or attack.code_ptr == "VAR_IOF") and attack.technique == "INDIRECT") :
			return False;
		

		if (attack.location == "HEAP" and attack.technique == "INDIRECT") :
			return False;
		
	elif (attack.code_ptr == "VAR_BOF" or
		attack.code_ptr == "VAR_IOF" or
		attack.code_ptr == "VAR_LEAK") :
		return False;
	

	if( attack.location == "STACK" ):
		if ((attack.technique == "DIRECT")) :
			if ((attack.code_ptr == "FUNC_PTR_HEAP") or
			  (attack.code_ptr == "FUNC_PTR_BSS") or
			  (attack.code_ptr == "FUNC_PTR_DATA") or
			  (attack.code_ptr == "LONGJMP_BUF_HEAP") or
			  (attack.code_ptr == "LONGJMP_BUF_DATA") or
			  (attack.code_ptr == "LONGJMP_BUF_BSS") or
			  (attack.code_ptr == "STRUCT_FUNC_PTR_HEAP") or
			  (attack.code_ptr == "STRUCT_FUNC_PTR_DATA") or
			  (attack.code_ptr == "STRUCT_FUNC_PTR_BSS") ) :
			
				return False;
			elif ((attack.code_ptr == "FUNC_PTR_STACK_PARAM") and
			  ((attack.function == "STRCAT") or
			  (attack.function == "SNPRINTF") or
			  (attack.function == "SSCANF") or
			  (attack.function == "HOMEBREW"))) : 
			
				return False;
				

	if( attack.location == "HEAP" ):
		if ((attack.technique == "DIRECT") and
		  ((attack.code_ptr == "RET_ADDR") or
		  (attack.code_ptr == "FUNC_PTR_STACK_VAR") or
		  (attack.code_ptr == "FUNC_PTR_STACK_PARAM") or
		  (attack.code_ptr == "FUNC_PTR_BSS") or
		  (attack.code_ptr == "FUNC_PTR_DATA") or
		  (attack.code_ptr == "LONGJMP_BUF_STACK_VAR") or
		  (attack.code_ptr == "LONGJMP_BUF_STACK_PARAM") or
		  (attack.code_ptr == "LONGJMP_BUF_BSS") or
		  (attack.code_ptr == "LONGJMP_BUF_DATA") or
		  (attack.code_ptr == "STRUCT_FUNC_PTR_STACK") or
		  (attack.code_ptr == "STRUCT_FUNC_PTR_DATA") or
		  (attack.code_ptr == "STRUCT_FUNC_PTR_BSS") )) :
		
			return False;
		
		

	if( attack.location == "DATA" ):
		if ((attack.technique == "DIRECT") and
		  ((attack.code_ptr == "RET_ADDR") or
		  (attack.code_ptr == "FUNC_PTR_STACK_VAR") or
		  (attack.code_ptr == "FUNC_PTR_STACK_PARAM") or
		  (attack.code_ptr == "FUNC_PTR_BSS") or
		  (attack.code_ptr == "FUNC_PTR_HEAP") or
		  (attack.code_ptr == "LONGJMP_BUF_STACK_VAR") or
		  (attack.code_ptr == "LONGJMP_BUF_STACK_PARAM") or
		  (attack.code_ptr == "LONGJMP_BUF_HEAP") or
		  (attack.code_ptr == "LONGJMP_BUF_BSS") or
		  (attack.code_ptr == "STRUCT_FUNC_PTR_STACK") or
		  (attack.code_ptr == "STRUCT_FUNC_PTR_HEAP") or
		  (attack.code_ptr == "STRUCT_FUNC_PTR_BSS") )) :
		
			return False;
		



	if( attack.location == "BSS" ):
			if ((attack.technique == "DIRECT") and
			  ((attack.code_ptr == "RET_ADDR") or
			  (attack.code_ptr == "FUNC_PTR_STACK_VAR") or
			  (attack.code_ptr == "FUNC_PTR_STACK_PARAM") or
			  (attack.code_ptr == "FUNC_PTR_DATA") or
			  (attack.code_ptr == "FUNC_PTR_HEAP") or
			  (attack.code_ptr == "LONGJMP_BUF_STACK_VAR") or
			  (attack.code_ptr == "LONGJMP_BUF_STACK_PARAM") or
			  (attack.code_ptr == "LONGJMP_BUF_HEAP") or
			  (attack.code_ptr == "LONGJMP_BUF_DATA") or
			  (attack.code_ptr == "STRUCT_FUNC_PTR_STACK") or
			  (attack.code_ptr == "STRUCT_FUNC_PTR_HEAP") or
			  (attack.code_ptr == "STRUCT_FUNC_PTR_DATA") )) : 
				
				return False;
			elif ((attack.technique == "INDIRECT") and
			  (attack.code_ptr == "LONGJMP_BUF_HEAP") and
			  (not(attack.function == "MEMCPY") and
			  not(attack.function == "STRNCPY") and
			  not(attack.function == "HOMEBREW"))) :
				return False;

	return True;




def do_each_tests() :
	scoreboard=[]
	nb = 0
	for t in tecniques : 
		for i in inject_params :
			for c in code_ptrs : 
				for l in locations :
					for f in functions :
						attaque = Attack(t, i, c, l, f, ATTACK_MODIFIED_FILEPATH, RIPE_FILEPATH_MOD)
						if is_OK(attaque) :
							print(f"\n====== ATTACK SCENARIO {nb} =========\n")
							
							# setup technique 
							attaque.setup()
							
							# build
							attaque.build()

							# run 
							result=attaque.run()
			
							
							new_node = attaque.to_dict()
							
							# evaluate
							if b"function reached." in result or b"Secret data leaked" in result :
								new_node["result"] = False
							else :
								new_node["result"] = True
							
							scoreboard.append(new_node)

							if VERBOSE : 	
								try :
									result = result.decode("utf-8")
								except Exception :
									print("NOT PRINTABLE")
								finally : 	
									print(result)
						nb += 1	

	scoreboard_pd = pd.DataFrame(scoreboard)
	scoreboard_pd.to_excel(EXCEL_OK_ATTACKS)
	return scoreboard
	


def display_attack_scoreboard(scoreboard, attack_nb=linspace(1, 10, 10, dtype=int)) :
	print("\n\n\n==============\nATTACK SCOREBOARD\n==============\n\n\n")
	for i in range(0,len(attack_nb)) :
		print(attacks_array[attack_nb[i]-1].replace(";", "\n"))
		if scoreboard[i] :
			print("\U0000274C" + f" attack attack_nb[i] not prevented\n\n".upper())
		else : 
			print("\U00002705" + f" attack attack_nb[i] prevented\n\n".upper())




do_each_tests()
# scoreboard = attack(CHOSEN_ATTACK)
# display_attack_scoreboard(scoreboard, CHOSEN_ATTACK)


