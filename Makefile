include Makefile.flags

SUBDIRS := boot  driver  fs  include  init  kernel  lib  mm tools

all: clean fairy.img run

#fairy.img: boot.bin setup.bin kernel.bin
fairy.img: boot.bin
	@dd if=/dev/zero of=fairy.img  bs=512 count=2880
	@cat boot.bin > tmp.img
	@dd if=tmp.img of=fairy.img bs=512 count=2880 conv=notrunc

boot.bin:
	nasm -o boot.bin -f bin boot/boot.S

setup.bin:
	@make -C boot setup

clean:
	rm -rf *.bin *.o fairy.img 

run: fairy.img
	@echo you can run qemu
	@qemu-system-i386 -fda fairy.img -boot a -m 64M -vnc 0.0.0.0:0

.PYONY: all clean

