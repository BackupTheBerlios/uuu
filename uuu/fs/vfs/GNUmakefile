# $Header: /home/xubuntu/berlios_backup/github/tmp-cvs/uuu/Repository/uuu/fs/vfs/GNUmakefile,v 1.1 2003/12/31 18:56:38 bitglue Exp $

UUUROOT=../..

OBJS = vfs.o

.PHONY: all
all: $(OBJS)

.PHONY: clean
clean: basic-clean
	rm -f *.o

include $(UUUROOT)/Make.config
-include $(OBJS:.o=.d)
