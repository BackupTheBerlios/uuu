# $Header: /home/xubuntu/berlios_backup/github/tmp-cvs/uuu/Repository/toolchain/mkudbfs/GNUmakefile,v 1.8 2003/10/27 00:30:03 bitglue Exp $

include ../Make.conf

.PHONY: clean install

mkudbfs: mkudbfs.c
	$(compiling) '$@'
	$(CC) -o mkudbfs $(CPPFLAGS) $(CFLAGS) mkudbfs.c

clean:
	rm -f mkudbfs *.d

install: mkudbfs
	$(installing) 'mkudbfs' in '$(BINDIR)'
	cp mkudbfs '$(BINDIR)'

-include mkudbfs.d
