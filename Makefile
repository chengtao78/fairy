include Makefile.flags

#SUBDIRS := boot driver fs include init kernel lib mm tools
SUBDIRS := init

KERNEL_LIBS := init/init.a

all: clean fairy.img run

fairy.img: boot.bin setup.bin kernel.bin
	@dd if=/dev/zero of=fairy.img bs=512 count=2880
	@cat boot.bin setup.bin kernel.bin > _fairy.img
	@dd if=_fairy.img of=fairy.img bs=512 count=2880 conv=notrunc

boot.bin:
	nasm -o boot.bin -f bin boot/boot.S

setup.bin:
	nasm -o setup.bin -f bin boot/setup.S

kernel.bin:
	@for d in $(SUBDIRS); do make -C $$d; done
	ld -melf_i386 $(KERNEL_LIBS) -Ttext 0xC0100000 -e start_kernel -o _kernel.bin
	objcopy -O binary -R .note -R .comment -S _kernel.bin kernel.bin

clean:
	rm -rf *.bin *.img *.tmp *.o fairy.img 
	@for d in $(SUBDIRS); do make -C $$d clean; done

run: fairy.img
	qemu-system-i386 -fda fairy.img -boot a -m 256M -vnc 0.0.0.0:0 -monitor stdio

.PYONY: all clean

