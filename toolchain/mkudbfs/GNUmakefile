# $Header: /home/xubuntu/berlios_backup/github/tmp-cvs/uuu/Repository/toolchain/mkudbfs/GNUmakefile,v 1.4 2003/10/13 21:26:08 bitglue Exp $

include ../Make.conf

.PHONY: clean install

mkudbfs: mkudbfs.c mkudbfs.h
	$(CC) -o mkudbfs $(CPPFLAGS) $(CFLAGS) mkudbfs.c

clean:
	rm -f mkudbfs

install: mkudbfs
	cp mkudbfs "$(BINDIR)"
