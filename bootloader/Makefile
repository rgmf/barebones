floppy.img: bootloader.bin os.bin
	dd if=bootloader.bin of=floppy.img
	dd if=os.bin of=floppy.img seek=1 bs=512

bootloader.bin: bootloader.o functions.o
	ld -Ttext=0x7c00 --oformat=binary bootloader.o -o bootloader.bin

bootloader.o: bootloader.S
	as bootloader.S -o bootloader.o

os.bin: os.o bootloader.o functions.o
	ld -Ttext=0x1000 --oformat=binary os.o -o os.bin

os.o: os.S
	as os.S -o os.o

bochs: bochsrc.txt
	bochs -f bochsrc.txt -q

clean:
	rm *.o *.bin
