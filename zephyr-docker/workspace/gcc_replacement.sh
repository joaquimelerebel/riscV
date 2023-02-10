#!/bin/sh
exec /opt/toolchains/zephyr-sdk-0.15.1/riscv64-zephyr-elf/bin/riscv64-zephyr-elf-gcc.real -fplugin=/workdir/inst_plugin_cfi.so "$@"
