floppy.img: bootloader.bin os.bin
	dd if=bootloader.bin of=floppy.img
	dd if=os.bin of=floppy.img seek=1 bs=512

bootloader.bin: bootloader.o
	ld -Ttext=0x7c00 --oformat=binary $^ -o $@

os.bin: os.o
	ld -Ttext=0x1000 --oformat=binary $^ -o $@

%.o: %.S
	as $^ -o $@

bochs: bochsrc.txt
	bochs -f bochsrc.txt -q

clean:
	rm *.o *.bin
