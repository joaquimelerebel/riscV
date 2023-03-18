#!/usr/bin/python3

import os
import glob
import shutil
from os import environ

WORKDIR_PATH = environ.get('WORKDIR_PATH')
ZEPHYR_SDK_PATH = environ.get('ZEPHYR_SDK_PATH')

if WORKDIR_PATH is None:
  WORKDIR_PATH = input('Workdir Path (/workdir): ') or "/workdir"

if ZEPHYR_SDK_PATH is None:
  ZEPHYR_SDK_PATH = input('Zephyr SDK Path (/opt/toolchains/zephyr-sdk-0.15.1): ') or "/opt/toolchains/zephyr-sdk-0.15.1"

def copy_and_backup(src, dst, ext='.old'):
  if os.path.exists(dst + ext):
    print(dst, 'is already backed')
  else:
    print('backing in', dst + ext)
    shutil.move(dst, dst + ext)

  shutil.copyfile(src, dst)


ZEPHYR_FILES_TREE = {
  'include/zephyr/arch/riscv': [
    './csr.h'
  ],
  'include/zephyr/toolchain': [
    './mwdt.h', './gcc.h'
  ],
  'arch/riscv/core': [
    './isr.S', './reset.S', './switch.S'
  ],
  'kernel': [
    './init.c', './Kconfig'
  ]
}

print("Copying zephyr files", end=" ")
for path, files in ZEPHYR_FILES_TREE.items():
  for file in files:
    copy_and_backup(file, os.path.join(WORKDIR_PATH, 'zephyr', path, file))

print('✅')

print("copying libc files", end=" ")

LIBC_FILES = ['./libc.a', './libg.a', './libm.a']

for libc_file in LIBC_FILES:
  files = glob.glob(os.path.join(ZEPHYR_SDK_PATH, 'riscv64-zephyr-elf/riscv64-zephyr-elf/lib/**/**/', libc_file))
  files.append(os.path.join(ZEPHYR_SDK_PATH, 'riscv64-zephyr-elf/riscv64-zephyr-elf/lib/', libc_file)) 
  for file in files:
    copy_and_backup(libc_file, file)

print('✅')

print("copying libgcc files", end=" ")

LIBGCC_FILES = ['./libgcc.a']

for libgcc_file in LIBGCC_FILES:
  files = glob.glob(os.path.join(ZEPHYR_SDK_PATH, 'riscv64-zephyr-elf/lib/gcc/riscv64-zephyr-elf/**/**/**/', libgcc_file))
  files.append(os.path.join(ZEPHYR_SDK_PATH, 'riscv64-zephyr-elf/lib/gcc/riscv64-zephyr-elf/12.1.0', libgcc_file)) # TODO: remove Hardcoding
  for file in files:
    copy_and_backup(libgcc_file, file)

print('✅')