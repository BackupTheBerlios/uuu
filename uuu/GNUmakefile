# $Header: /home/xubuntu/berlios_backup/github/tmp-cvs/uuu/Repository/uuu/GNUmakefile,v 1.2 2003/10/03 22:58:09 bitglue Exp $

UUUROOT=$(CURDIR)

all: diskimage

.PHONY: diskimage
diskimage:
	$(entering) $(CURDIR)/sys/bootloader
	$(MAKE) -C sys/bootloader $(UUUROOT)/diskimage diskimage=$(UUUROOT)/diskimage
	$(entering) $(CURDIR)

.PHONY: clean
clean:
	rm -f diskimage
	$(MAKE) -C sys/bootloader clean

include Make.config
