# $Header: /home/xubuntu/berlios_backup/github/tmp-cvs/uuu/Repository/uuu/sys/memory_manager/Attic/GNUmakefile,v 1.2 2003/12/31 03:22:44 bitglue Exp $

UUUROOT=../..

.PHONY: all clean
all:
	$(entering) $(CURDIR)/$(ARCH)
	$(MAKE) -C $(ARCH) $@
	$(entering) $(CURDIR)

clean: basic-clean
	rm -f *.o

memory_manager.o:
	$(entering) $(CURDIR)/$(ARCH)
	$(MAKE) -C $(ARCH) noblame.o
	$(entering) $(CURDIR)
	cp $(ARCH)/noblame.o "$@"

include $(UUUROOT)/Make.config
