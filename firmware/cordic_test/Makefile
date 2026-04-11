RISCV_PREFIX ?= /home/fy2243/ECE9433-SoC-Design-Project-Claude/third_party/riscv-toolchain/bin/riscv-none-elf-
CC      := $(RISCV_PREFIX)gcc
OBJCOPY := $(RISCV_PREFIX)objcopy
CFLAGS  := -Os -march=rv32im -mabi=ilp32 -ffreestanding -nostdlib
LDFLAGS := -T link.ld -nostartfiles -Wl,--build-id=none,--strip-debug

all: cordic_test.hex

cordic_test.elf: start.S cordic_test.c link.ld
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ start.S cordic_test.c

cordic_test.bin: cordic_test.elf
	$(OBJCOPY) -O binary $< $@
	chmod -x $@

cordic_test.hex: cordic_test.elf
	$(OBJCOPY) -O verilog --verilog-data-width=4 cordic_test.elf $@

clean:
	rm -f cordic_test.elf cordic_test.bin cordic_test.hex

.PHONY: all clean
