# $Header: /home/xubuntu/berlios_backup/github/tmp-cvs/uuu/Repository/uuu/sys/bootloader/GNUmakefile,v 1.4 2003/12/31 03:22:44 bitglue Exp $

UUUROOT=../..

.PHONY: all $(diskimage)
all $(diskimage) stage2:
	$(entering) $(CURDIR)/$(ARCH)
	@$(MAKE) -C $(ARCH) $@ diskimage=$(diskimage)
	$(entering) $(CURDIR)

clean: basic-clean
	rm -f *.o


include $(UUUROOT)/Make.config
