# $Header: /home/xubuntu/berlios_backup/github/tmp-cvs/uuu/Repository/uuu/sys/bootloader/x86/GNUmakefile,v 1.2 2003/10/03 22:58:09 bitglue Exp $

UUUROOT=../../..

.PHONY: all
all: stage1.bin stage2.bin

$(diskimage): stage1.bin stage2.bin
	$(generating) "disk image"
	dd if=/dev/zero of=$@ count=2880 2> /dev/null
	$(MKUDBFS) $@ stage2.bin > /dev/null
	dd if=stage1.bin of=$(diskimage) count=1 conv=notrunc 2> /dev/null

.PHONY: clean
clean: basic-clean
	rm -f font.inc *.bin

font.inc: font.src
	$(generating) "font"
	./mkfont.py < font.src > font.inc

include $(UUUROOT)/Make.config
-include stage1.d stage2.d

# have to make font.inc before making the deps or nasm will puke
stage2.d: font.inc
