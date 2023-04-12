#!/usr/bin/python3

import os
import sys
import glob
import shutil
from os import environ
from termcolors import fg, style

WORKDIR_PATH = environ.get('WORKDIR_PATH')
ZEPHYR_SDK_PATH = environ.get('ZEPHYR_SK_PATH')

if WORKDIR_PATH is None:
  WORKDIR_PATH = input('Workdir Path (/workdir): ') or "/workdir"

if ZEPHYR_SDK_PATH is None:
  ZEPHYR_SDK_PATH = input('Zephyr SDK Path (/opt/toolchains/zephyr-sdk-0.15.1): ') or "/opt/toolchains/zephyr-sdk-0.15.1"

def copy_and_backup(src, dst, ext='.old'):
  if os.path.exists(dst + ext):
    print(fg.YELLOW, dst, 'is already backed', fg.RESET)
  else:
    print(fg.GREEN, style.DIM, 'backing in', dst + ext, style.RESET_ALL)
    shutil.move(dst, dst + ext)

  shutil.copyfile(src, dst)

def revert_backup(src, dst, ext='.old'):
  if not os.path.exists(dst + ext):
    print(fg.YELLOW, f'{src} is not backed, keeping it as is.', fg.RESET)
  else:
    shutil.move(dst + ext, dst)
    print(fg.GREEN, style.DIM, f'{src} backed up successfully', style.RESET_ALL);

is_revert = len(sys.argv) > 1 and sys.argv[1] == 'revert'
action = 'reverting' if is_revert else 'copying'
fn = revert_backup if is_revert else copy_and_backup

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
  ],
  'lib/libc/newlib': [
    'libc-hooks.c'
  ],
  'soc/riscv/riscv-privilege/virt': [
    'Kconfig.soc'
  ],
  'boards/riscv/cv32a6_zybo' : [
    './cv32a6_zybo_defconfig'
  ]
}

print(action, "zephyr files", end=" ")
for path, files in ZEPHYR_FILES_TREE.items():
  for file in files:
    fn(file, os.path.join(WORKDIR_PATH, 'zephyr', path, file))

print('Done ✅')

# !TODO!: Make newlib without nano as well
print(action, "libc files", end=" ")

LIBC_FILES = ['./libc.a', './libg.a', './libm.a', './libc_nano.a', './libg_nano.a', './libm_nano.a']

for libc_file in LIBC_FILES:
  dst = os.path.join(ZEPHYR_SDK_PATH, 'riscv64-zephyr-elf/riscv64-zephyr-elf/lib/', libc_file)
  fn(libc_file, dst)

print('Done ✅')

print(action, "libgcc files", end=" ")

LIBGCC_FILES = ['./libgcc.a']

for libgcc_file in LIBGCC_FILES:
  dst = os.path.join(ZEPHYR_SDK_PATH, 'riscv64-zephyr-elf/lib/gcc/riscv64-zephyr-elf/12.1.0', libgcc_file)
  fn(libgcc_file, dst)

print('Done ✅')