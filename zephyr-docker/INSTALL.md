# Installation

## Installation des modifications

Dans le docker, appliquer les modifications via le script `install.sh` :

```
cd /workdir
sudo ./install.sh
```

Par exemple pour compiler le benchmark :
```
west build -p -b cv32a6_zybo /workdir/perf_baseline/
west build -t run
```

Pour compiler la version QEMU on utilise la commande :
```
west build -p -b qemu_riscv32 /workdir/perf_baseline/
```

**Note : à cause de nos modifications hardware il n'est pas possible d'exécuter le code compilé directement dans le QEMU fournit par défaut. Voir la section suivante pour compiler QEMU avec une simulation des modifications hardware.**

## Installation de QEMU (optionnel)

Nous utilisons qemu pour tester nos modifications software et hardware sans déployer le code sur le FPGA. Dans le cadre de l'évaluation finale de la solution il n'est pas nécessaire d'installer QEMU. Les commandes suivantes sont à executer sur la machine hôte.

```bash
# Clone qemu
git clone https://github.com/qemu/qemu.git
cd qemu
git checkout 627634031092e1514f363fd8659a579398de0f0e

# Apply patch
git apply ../path/to/.../zephyr-docker/workspace/zephyr-patch/patches/qemu_patch

# Compile qemu
mkdir build
cd build
../configure --target-list=riscv32-softmmu
make -j$(nproc)
```

Après avoir compilé zephyr dans le docker, on le lance dans QEMU sur le système hôte (phase de simulation):

```bash
./qemu-system-riscv32 -nographic -machine virt -bios none -m 256 -net none -pidfile qemu.pid -chardev stdio,id=con,mux=on -serial chardev:con -mon chardev=con,mode=readline -icount shift=6,align=off,sleep=off -rtc clock=vm -kernel  ../../../riscV/zephyr-docker/workspace/build/zephyr/zephyr.elf
```