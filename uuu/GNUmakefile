# $Header: /home/xubuntu/berlios_backup/github/tmp-cvs/uuu/Repository/uuu/GNUmakefile,v 1.3 2003/10/13 01:14:55 bitglue Exp $

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
	$(entering) $(CURDIR)/sys/bootloader
	$(MAKE) -C sys/bootloader clean
	$(entering) $(CURDIR)

include Make.config
