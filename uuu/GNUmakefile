# $Header: /home/xubuntu/berlios_backup/github/tmp-cvs/uuu/Repository/uuu/GNUmakefile,v 1.1 2003/10/03 19:41:45 bitglue Exp $

UUUROOT=$(CURDIR)

all: diskimage

.PHONY: diskimage
diskimage:
	@$(MAKE) -C sys/bootloader $(UUUROOT)/diskimage diskimage=$(UUUROOT)/diskimage

.PHONY: clean
clean:
	rm -f diskimage
	@$(MAKE) -C sys/bootloader clean
