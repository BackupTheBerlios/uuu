UUUROOT=../../..

.PHONY: all
all: stage1.bin stage2.bin

$(diskimage): stage1.bin stage2.bin
	dd if=/dev/zero of=$@ count=2880
	$(MKUDBFS) $@ stage2.bin
	dd if=stage1.bin of=$(diskimage) count=1 conv=notrunc

.PHONY: clean
clean: basic-clean
	rm -f font.inc *.bin

font.inc: font.src
	./mkfont.py < font.src > font.inc

include $(UUUROOT)/Make.config
-include stage1.d stage2.d

# have to make font.inc before making the deps or nasm will puke
stage2.d: font.inc
