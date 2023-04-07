#!/bin/sh

# apply changes to the libs 
export WORKDIR_PATH=/workdir
export ZEPHYR_SDK_PATH=/opt/toolchains/zephyr-sdk-0.15.1


# Install modifications
cd /workdir/zephyr-patch
echo "\n\n" | sudo /workdir/zephyr-patch/copy-zephyr-files.py

# Install GCC
cd /opt/toolchains/zephyr-sdk-0.15.1/riscv64-zephyr-elf/bin/

cat << EOF > riscv64-zephyr-elf-gcc.wrapper
#!/bin/sh
exec /opt/toolchains/zephyr-sdk-0.15.1/riscv64-zephyr-elf/bin/riscv64-zephyr-elf-gcc.real -fplugin=/workdir/inst_plugin_cfi.so "\$@"
EOF
sudo chmod +x riscv64-zephyr-elf-gcc.wrapper

sudo mv riscv64-zephyr-elf-gcc riscv64-zephyr-elf-gcc.real
sudo ln -s riscv64-zephyr-elf-gcc.wrapper riscv64-zephyr-elf-gcc
sudo chmod +x riscv64-zephyr-elf-gcc
