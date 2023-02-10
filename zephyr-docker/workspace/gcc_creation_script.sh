#!/bin/sh
cd /opt/toolchains/zephyr-sdk-0.15.1/riscv64-zephyr-elf/bin/

cat /workdir/gcc_replacement.sh > riscv64-zephyr-elf-gcc.wrapper
sudo chmod +x riscv64-zephyr-elf-gcc.wrapper

sudo mv riscv64-zephyr-elf-gcc riscv64-zephyr-elf-gcc.real
sudo ln -s riscv64-zephyr-elf-gcc.wrapper riscv64-zephyr-elf-gcc
sudo chmod +x riscv64-zephyr-elf-gcc
