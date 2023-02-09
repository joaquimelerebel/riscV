# GCC Plugin

Compile a plugin for gcc 12. 

Dependencies:

```bash
apt install gcc-12-plugin-dev
```

## Usage

Compile the plugin
```bash
make
```

Copy it to the docker workdir

```bash
cp inst_plugin_cfi.so ../zephyr-docker/workspace/inst_plugin_cfi.so
```

In docker:
```bash
# Create gcc wrapper
cat << EOF | sudo tee /opt/toolchains/zephyr-sdk-0.15.1/riscv64-zephyr-elf/bin/riscv64-zephyr-elf-gcc.wrapper
#!/bin/sh

exec /opt/toolchains/zephyr-sdk-0.15.1/riscv64-zephyr-elf/bin/riscv64-zephyr-elf-gcc.real -fplugin=/workdir/inst_plugin_cfi.so "\$@"
EOF

# Make it executable
sudo chmod +x /opt/toolchains/zephyr-sdk-0.15.1/riscv64-zephyr-elf/bin/riscv64-zephyr-elf-gcc.wrapper

# Backup the real gcc
sudo cp /opt/toolchains/zephyr-sdk-0.15.1/riscv64-zephyr-elf/bin/riscv64-zephyr-elf-gcc{,.real}

# Link gcc to the wrapper
sudo rm /opt/toolchains/zephyr-sdk-0.15.1/riscv64-zephyr-elf/bin/riscv64-zephyr-elf-gcc && sudo ln -s /opt/toolchains/zephyr-sdk-0.15.1/riscv64-zephyr-elf/bin/riscv64-zephyr-elf-gcc{.wrapper,}

# To restore real gcc use the following command
# sudo rm /opt/toolchains/zephyr-sdk-0.15.1/riscv64-zephyr-elf/bin/riscv64-zephyr-elf-gcc && sudo ln -s /opt/toolchains/zephyr-sdk-0.15.1/riscv64-zephyr-elf/bin/riscv64-zephyr-elf-gcc{.real,}
```

