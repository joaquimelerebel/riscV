#!/bin/sh

# apply changes to the libs 
export WORKDIR_PATH=/workdir
export ZEPHYR_SDK_PATH=/opt/toolchains/zephyr-sdk-0.15.1


# Install modifications
cd /workdir/zephyr-patch
echo "\n\n\n" | sudo /workdir/zephyr-patch/copy-files.py

# Install GCC
cd /opt/toolchains/zephyr-sdk-0.15.1/riscv64-zephyr-elf/bin/

cat << EOF | sudo tee riscv64-zephyr-elf-gcc.wrapper
#!/bin/sh
exec /opt/toolchains/zephyr-sdk-0.15.1/riscv64-zephyr-elf/bin/riscv64-zephyr-elf-gcc.real -fplugin=/workdir/zephyr-patch/gcc/inst_plugin_cfi.so "\$@"
EOF
sudo chmod +x riscv64-zephyr-elf-gcc.wrapper

# Only copy original gcc to gcc.real if it doesn't exist yet, otherwise it means that gcc is a link to gcc.wrapper
if [ ! -f riscv64-zephyr-elf-gcc.real ]; then
    sudo mv riscv64-zephyr-elf-gcc riscv64-zephyr-elf-gcc.real
fi
sudo ln -fs riscv64-zephyr-elf-gcc.wrapper riscv64-zephyr-elf-gcc
sudo chmod +x riscv64-zephyr-elf-gcc
