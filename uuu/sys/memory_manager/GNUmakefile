# $Header: /home/xubuntu/berlios_backup/github/tmp-cvs/uuu/Repository/uuu/sys/memory_manager/Attic/GNUmakefile,v 1.1 2003/12/26 21:32:55 bitglue Exp $

UUUROOT=../..

.PHONY: all clean
all clean:
	$(entering) $(CURDIR)/$(ARCH)
	$(MAKE) -C $(ARCH) $@
	$(entering) $(CURDIR)

memory_manager.o:
	$(entering) $(CURDIR)/$(ARCH)
	$(MAKE) -C $(ARCH) noblame.o
	$(entering) $(CURDIR)
	cp $(ARCH)/noblame.o "$@"

include $(UUUROOT)/Make.config
