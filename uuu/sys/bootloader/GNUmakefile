# $Header: /home/xubuntu/berlios_backup/github/tmp-cvs/uuu/Repository/uuu/sys/bootloader/GNUmakefile,v 1.3 2003/12/23 20:48:59 bitglue Exp $

UUUROOT=../..

.PHONY: all $(diskimage) clean
all $(diskimage) clean stage2:
	$(entering) $(CURDIR)/$(ARCH)
	@$(MAKE) -C $(ARCH) $@ diskimage=$(diskimage)
	$(entering) $(CURDIR)

include $(UUUROOT)/Make.config
