# $Header: /home/xubuntu/berlios_backup/github/tmp-cvs/uuu/Repository/uuu/GNUmakefile,v 1.7 2003/12/31 18:34:44 bitglue Exp $

UUUROOT=$(CURDIR)

all: diskimage

include $(UUUROOT)/Make.config
include $(UUUROOT)/sys/bimage/$(ARCH)/Make.config
-include sourcefiles

diskimage: boot.bimage

.PHONY: boot.o
boot.o: $(BIMAGE_OBJS)
	$(linking) '$^  >  $@'
	ld -static -s -o '$@' -T sys/bimage/$(ARCH)/bimage.ld $(BIMAGE_OBJS)

boot.bimage: boot.o
	$(MKUUUBIMAGE) -o '$@' '$<'
	$(generating) '$<  >  $@'

.PHONY: diskimage
diskimage:
	$(entering) $(CURDIR)/sys/bootloader
	$(MAKE) -C sys/bootloader $(UUUROOT)/diskimage diskimage=$(UUUROOT)/diskimage
	$(entering) $(CURDIR)

.PHONY: grub
grub: boot.bimage
	$(entering) $(CURDIR)/sys/bootloader
	$(MAKE) -C sys/bootloader stage2
	$(entering) $(CURDIR)

.PHONY: clean
clean:
	for dir in $(sort $(dir $(BIMAGE_OBJS)) $(dir $(SOURCEFILES)) ); do \
	  $(cleaning) "$$dir"; \
	  $(MAKE) -C "$$dir" clean; \
	done
	$(cleaning) '$(CURDIR)'
	rm -f diskimage boot.o boot.bimage sourcefiles
	rm -f uuudoc/uuudoc.xml
	rm -f include/ret_counts.asm

.PHONY: $(BIMAGE_OBJS)
$(BIMAGE_OBJS): include/ret_counts.asm
	$(entering) '$(dir $@)'
	$(MAKE) -C '$(dir $@)' '$(notdir $@)'
	$(entering) $(CURDIR)

.PHONY: new_files
new_files:
	rm -f sourcefiles

uuudoc/uuudoc.xml: $(SOURCEFILES)
	$(generating) '$@'
	uuudoc/extractuuudoc.pl `find -name '*.asm'` > "$@"

sourcefiles: $(SOURCEFILES)
	$(generating) '$@'
	echo 'SOURCEFILES = \' > '$@'
	for file in `find $(addprefix $(UUUROOT)/,$(SOURCE_DIRS)) -name '*.asm'`; do echo "$$file \\" >> '$@'; done
	echo >> '$@'

include/ret_counts.asm: uuudoc/ret_counts.xsl uuudoc/uuudoc.xml
	$(generating) '$@'
	$(XSLTPROC) $^ > '$@'

