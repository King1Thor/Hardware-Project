#!/usr/bin/env bash
# Build a C program into the unified physical RAM (rtl/ah_mem.v).
# usage: tools/ah_build_uni.sh sw/memtest.c
set -e
ROOT=$(cd "$(dirname "$0")/.." && pwd)
SRC=${1:-$ROOT/sw/memtest.c}
GCC=riscv64-unknown-elf-gcc
MARCH=rv64ima_zicsr
LIBGCC=$($GCC -march=$MARCH -mabi=lp64 -mcmodel=medany -print-libgcc-file-name)
O=$(mktemp -d)
# NOTE: -mcmodel=medany is required to address the 0x80000000 RAM base.
$GCC -march=$MARCH -mabi=lp64 -mcmodel=medany -O1 -ffreestanding -nostdlib -nostartfiles \
   -T $ROOT/sw/link_uni.ld $ROOT/sw/crt0_uni.S "$SRC" "$LIBGCC" -o $O/a.elf
riscv64-unknown-elf-objcopy -O binary $O/a.elf $O/a.bin
python3 $ROOT/tools/ah_mkmem.py $ROOT/rtl/ah_mem.v $O/a.bin
echo "built $SRC -> rtl/ah_mem.v"
