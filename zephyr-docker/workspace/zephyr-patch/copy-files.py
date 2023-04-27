#!/usr/bin/python3

import os
import sys
import glob
import shutil
from os import environ
from termcolors import fg, style

WORKDIR_PATH = environ.get('WORKDIR_PATH')
ZEPHYR_SDK_PATH = environ.get('ZEPHYR_SK_PATH')
NEWLIB_NANO_O = environ.get('NEWLIB_NANO_O')

if WORKDIR_PATH is None:
  WORKDIR_PATH = input('Workdir Path (/workdir):') or "/workdir"

if ZEPHYR_SDK_PATH is None:
  ZEPHYR_SDK_PATH = input('Zephyr SDK Path (/opt/toolchains/zephyr-sdk-0.15.1): ') or "/opt/toolchains/zephyr-sdk-0.15.1"

if NEWLIB_NANO_O is None:
  NEWLIB_NANO_O = input('Newlib Nano Optimization (-O2):') or "O2"


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
    'csr.h'
  ],
  'include/zephyr/toolchain': [
    'mwdt.h', 'gcc.h'
  ],
  'arch/riscv/core': [
    'isr.S', 'reset.S', 'switch.S', 'fatal.c', 'thread.c'
  ],
  'kernel': [
    'init.c', 'Kconfig'
  ],
  'lib/libc/newlib': [
    'libc-hooks.c'
  ],
  'soc/riscv/riscv-privilege/virt': [
    'Kconfig.soc'
  ]
}

print(action, "zephyr files")

for path, files in ZEPHYR_FILES_TREE.items():
  for file in files:
    fullpath = os.path.join('zephyr', path, file)
    fn(fullpath, os.path.join(WORKDIR_PATH, fullpath))

print('Done ✅')

print(action, "libc files")

LIBC_FILES = ['newlib/libc.a', 'newlib/libm.a']
LIBC_NANO_FILES = ['newlib/nano/libc_nano.a', 'newlib/nano/libm_nano.a']
if NEWLIB_NANO_O == "O2":
  LIBC_NANO_FILES = ['newlib/nano/O2/libc_nano.a', 'newlib/nano/O2/libm_nano.a']

for libc_file in [*LIBC_FILES, *LIBC_NANO_FILES]:
  filename = os.path.basename(libc_file)
  dst = os.path.join(ZEPHYR_SDK_PATH, 'riscv64-zephyr-elf/riscv64-zephyr-elf/lib/', filename)
  fn(libc_file, dst)

print('Done ✅')

print(action, "libgcc files")

LIBGCC_FILES = ['gcc/libgcc.a']

for libgcc_file in LIBGCC_FILES:
  filename = os.path.basename(libgcc_file)
  dst = os.path.join(ZEPHYR_SDK_PATH, 'riscv64-zephyr-elf/lib/gcc/riscv64-zephyr-elf/12.1.0', filename)
  fn(libgcc_file, dst)

print('Done ✅')
