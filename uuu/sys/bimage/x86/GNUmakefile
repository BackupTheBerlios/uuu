# $Header: /home/xubuntu/berlios_backup/github/tmp-cvs/uuu/Repository/uuu/sys/bimage/x86/GNUmakefile,v 1.3 2003/12/31 18:34:44 bitglue Exp $

UUUROOT=../../..

OBJS = test.o

all: $(OBJS)
clean: basic-clean
	rm -f *.o

include $(UUUROOT)/Make.config
-include $(OBJS:.o=.d)
