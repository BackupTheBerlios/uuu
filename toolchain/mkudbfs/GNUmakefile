# $Header: /home/xubuntu/berlios_backup/github/tmp-cvs/uuu/Repository/toolchain/mkudbfs/GNUmakefile,v 1.7 2003/10/27 00:27:44 bitglue Exp $

include ../Make.conf

.PHONY: clean install

mkudbfs: mkudbfs.c
	$(compiling) '$@'
	$(CC) -o mkudbfs $(CPPFLAGS) $(CFLAGS) mkudbfs.c

clean:
	rm -f mkudbfs

install: mkudbfs
	$(installing) 'mkudbfs' in '$(BINDIR)'
	cp mkudbfs '$(BINDIR)'

-include mkudbfs.d
