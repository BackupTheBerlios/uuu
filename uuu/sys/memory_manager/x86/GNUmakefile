# $Header: /home/xubuntu/berlios_backup/github/tmp-cvs/uuu/Repository/uuu/sys/memory_manager/x86/GNUmakefile,v 1.1 2003/12/26 21:32:55 bitglue Exp $

UUUROOT=../../..

OBJS = noblame.o

.PHONY: all
all: $(OBJS)

.PHONY: clean
clean: basic-clean
	rm -f *.o

include $(UUUROOT)/Make.config
-include $(OBJS:.o=.d)
