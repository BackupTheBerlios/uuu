# $Header: /home/xubuntu/berlios_backup/github/tmp-cvs/uuu/Repository/uuu/util/debug/GNUmakefile,v 1.2 2003/12/31 18:34:44 bitglue Exp $

UUUROOT=../..

OBJS = diable.o

.PHONY: all
all: $(OBJS)

.PHONY: clean
clean: basic-clean
	rm -f *.o

include $(UUUROOT)/Make.config
-include $(OBJS:.o=.d)
