# $Header: /home/xubuntu/berlios_backup/github/tmp-cvs/uuu/Repository/uuu/GNUmakefile,v 1.4 2003/12/23 02:25:03 bitglue Exp $

UUUROOT=$(CURDIR)

all: diskimage

include $(UUUROOT)/Make.config
include $(UUUROOT)/sys/bimage/$(ARCH)/Make.config

diskimage: boot.bimage

.PHONY: boot.o
boot.o: $(BIMAGE_OBJS)
	ld -static -s -o '$@' -T sys/bimage/$(ARCH)/bimage.ld $(BIMAGE_OBJS)

boot.bimage: boot.o
	$(MKUUUBIMAGE) -o '$@' '$<'
	$(generating) '$<  >  $@'

.PHONY: diskimage
diskimage:
	$(entering) $(CURDIR)/sys/bootloader
	$(MAKE) -C sys/bootloader $(UUUROOT)/diskimage diskimage=$(UUUROOT)/diskimage
	$(entering) $(CURDIR)

.PHONY: clean
clean:
	rm -f diskimage boot.o boot.bimage
	$(entering) $(CURDIR)/sys/bootloader
	$(MAKE) -C sys/bootloader clean
	$(entering) $(CURDIR)

.PHONY: $(BIMAGE_OBJS)
$(BIMAGE_OBJS):
	$(MAKE) -C $(dir $@) $(notdir $@)

