# $Header: /home/xubuntu/berlios_backup/github/tmp-cvs/uuu/Repository/uuu/sys/bootloader/x86/GNUmakefile,v 1.12 2003/12/23 02:25:03 bitglue Exp $

UUUROOT=../../..

STAGE2_OBJS = stage2.o display.o command.o keyboard.o floppy.o ata.o boot.o multiboot.o

.PHONY: all
all: stage1.bin stage2

$(diskimage): stage1.bin stage2
	$(generating) '$@'
	dd if=/dev/zero of=$@ count=2880 2> /dev/null
	"$(MKUDBFS)" $(MKUDBFSFLAGS) "$@" > /dev/null
	dd if=stage1.bin of="$(diskimage)" count=1 conv=notrunc 2> /dev/null
	"$(UDB_INSTBOOT)" $(UDB_INSTBOOT_FLAGS) "$(diskimage)" stage2 > /dev/null

.PHONY: clean
clean: basic-clean
	rm -f font.inc *.bin *.o stage2 *.bimage

font.inc: font.src
	$(generating) '$<  >  $@'
	./mkfont.py < font.src > font.inc

stage2: stage2.ld $(STAGE2_OBJS)
	$(linking) '$(STAGE2_OBJS)  >  $@'
	ld -static -s -o '$@' -T stage2.ld $(STAGE2_OBJS) $(ZLIB_LDFLAGS)

include $(UUUROOT)/Make.config

-include stage1.d $(STAGE2_OBJS:.o=.d)

# have to make font.inc before making the deps or nasm will puke
display.d: font.inc

# nasm doesn't generate deps for incbin
boot.o: $(UUUROOT)/boot.bimage
