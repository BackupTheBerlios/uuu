# $Header: /home/xubuntu/berlios_backup/github/tmp-cvs/uuu/Repository/uuu/sys/scheduler/x86/GNUmakefile,v 1.1 2003/12/31 23:57:21 instinc Exp $

UUUROOT=../../..

OBJS = avalon.o

.PHONY: all
all: $(OBJS)

.PHONY: clean
clean: basic-clean
	rm -f *.o

include $(UUUROOT)/Make.config
-include $(OBJS:.o=.d)
