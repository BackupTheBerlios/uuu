# $Header: /home/xubuntu/berlios_backup/github/tmp-cvs/uuu/Repository/uuu/lib/queue/GNUmakefile,v 1.1 2004/01/03 03:05:54 instinc Exp $

UUUROOT=../..

OBJS = ring.o

.PHONY: all
all: $(OBJS)

.PHONY: clean
clean: basic-clean
	rm -f *.o

include $(UUUROOT)/Make.config
-include $(OBJS:.o=.d)
