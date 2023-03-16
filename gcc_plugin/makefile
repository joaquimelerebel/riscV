# The gcc used to compile our plugin (consider that is written in C++!)
HOST_GCC = g++

# The gcc that will support our plugin 
TARGET_GCC = gcc

RISCV_GCC = /opt/zephyr-sdk-0.15.1/riscv64-zephyr-elf/bin/riscv64-zephyr-elf-gcc.real
RISCV_OBJDUMP = /opt/zephyr-sdk-0.15.1/riscv64-zephyr-elf/bin/riscv64-zephyr-elf-objdump


# Plugins directory of GCC
GCC_PLUGINS_DIR = $(shell $(TARGET_GCC) -print-file-name=plugin)

# GCC CPP flags (we need position independent code and run time type info support disabled)
CXXFLAGS+= -I$(GCC_PLUGINS_DIR)/include -fPIC -fno-rtti

# our recipes
.PHONY: all clean test

all: riscv

inst_plugin_cfi.so: instrument_cfi.cpp
	$(HOST_GCC) -shared $(CXXFLAGS) $^ -o $@

riscv: inst_plugin_cfi.so
	$(RISCV_GCC) target.c -fplugin="$(shell pwd)/inst_plugin_cfi.so"  -g -O0 -o bin
	$(RISCV_OBJDUMP) -drwCS --no-addresses bin > bin.list

riscv_no_cfi:
	$(RISCV_GCC) target.c -g -O0 -o bin
	$(RISCV_OBJDUMP) -drwCS --no-addresses bin > bin.list


clean: 
	rm -f inst_plugin_cfi.so bin
