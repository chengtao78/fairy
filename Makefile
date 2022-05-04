include Makefile.flags

SUBDIRS := boot driver fs include init kernel lib mm tools

all: clean fairy.img run

#fairy.img: boot.bin setup.bin kernel.bin
fairy.img: boot.bin setup.bin
	@dd if=/dev/zero of=fairy.img bs=512 count=2880
	@cat boot.bin setup.bin > _fairy.img
	@dd if=_fairy.img of=fairy.img bs=512 count=2880 conv=notrunc

boot.bin:
	nasm -o boot.bin -f bin boot/boot.S

setup.bin:
	nasm -o setup.bin -f bin boot/setup.S

clean:
	rm -rf *.bin *.img *.o fairy.img 

run: fairy.img
	@qemu-system-i386 -fda fairy.img -boot a -m 256M -vnc 0.0.0.0:0 -monitor stdio

.PYONY: all clean

