# $Header: /home/xubuntu/berlios_backup/github/tmp-cvs/uuu/Repository/uuu/sys/bootloader/GNUmakefile,v 1.2 2003/10/03 22:58:09 bitglue Exp $

UUUROOT=../..

.PHONY: all $(diskimage) clean
all $(diskimage) clean:
	$(entering) $(CURDIR)/$(ARCH)
	@$(MAKE) -C $(ARCH) $@ diskimage=$(diskimage)
	$(entering) $(CURDIR)

include $(UUUROOT)/Make.config
