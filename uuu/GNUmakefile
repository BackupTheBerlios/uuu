# $Header: /home/xubuntu/berlios_backup/github/tmp-cvs/uuu/Repository/uuu/GNUmakefile,v 1.9 2004/01/05 16:32:53 bitglue Exp $

UUUROOT=$(CURDIR)

all: diskimage

include $(UUUROOT)/Make.config
include $(UUUROOT)/sys/bimage/$(ARCH)/Make.config
-include sourcefiles

diskimage: boot.bimage

.PHONY:
lib/c/bin-i386/dietlibc.a:
	$(entering) $(CURDIR)/lib/c
	$(MAKE) -C lib/c
	$(entering) $(CURDIR)

.PHONY: boot.o
boot.o: $(BIMAGE_OBJS) lib/c/bin-i386/dietlibc.a
	$(linking) '$^ >  $@'
	gcc -nostartfiles -static -s -o '$@' -Xlinker -T -Xlinker sys/bimage/$(ARCH)/bimage.ld $(BIMAGE_OBJS) lib/c/bin-i386/dietlibc.a

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
	$(cleaning) '$(CURDIR)/lib/c'
	$(MAKE) -C '$(CURDIR)/lib/c' clean
	$(cleaning) '$(CURDIR)/uuudoc'
	$(MAKE) -C '$(CURDIR)/uuudoc' clean
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

.PHONY: doc
doc:
	$(entering) $(CURDIR)/uuudoc
	$(MAKE) -C uuudoc all
	$(entering) $(CURDIR)

uuudoc/uuudoc.xml uuudoc/uuudoc.html: $(SOURCEFILES)
	$(entering) $(CURDIR)/uuudoc
	$(MAKE) -C uuudoc $(notdir $@)
	$(entering) $(CURDIR)

sourcefiles: $(SOURCEFILES)
	$(generating) '$@'
	echo 'SOURCEFILES = \' > '$@'
	for file in `find $(addprefix $(UUUROOT)/,$(SOURCE_DIRS)) -name '*.asm'`; do echo "$$file \\" >> '$@'; done
	echo >> '$@'

include/ret_counts.asm: uuudoc/ret_counts.xsl uuudoc/uuudoc.xml
	$(generating) '$@'
	$(XSLTPROC) $^ > '$@'
