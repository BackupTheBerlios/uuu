# $Header: /home/xubuntu/berlios_backup/github/tmp-cvs/uuu/Repository/uuu/sys/bootloader/x86/GNUmakefile,v 1.4 2003/10/23 03:11:01 bitglue Exp $

UUUROOT=../../..

.PHONY: all
all: stage1.bin stage2.bin

$(diskimage): stage1.bin stage2.bin
	$(generating) "$@"
	dd if=/dev/zero of=$@ count=2880 2> /dev/null
	"$(MKUDBFS)" $(MKUDBFSFLAGS) "$@" > /dev/null
	dd if=stage1.bin of="$(diskimage)" count=1 conv=notrunc 2> /dev/null
	"$(UDB_INSTBOOT)" $(UDB_INSTBOOT_FLAGS) "$(diskimage)" stage2.bin > /dev/null

.PHONY: clean
clean: basic-clean
	rm -f font.inc *.bin

font.inc: font.src
	$(generating) "$@"
	./mkfont.py < font.src > font.inc

include $(UUUROOT)/Make.config

ASFLAGS += -dBOOT_CONSOLE=$(BOOT_CONSOLE)

-include stage1.d stage2.d

# have to make font.inc before making the deps or nasm will puke
stage2.d: font.inc
