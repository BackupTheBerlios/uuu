# $Header: /home/xubuntu/berlios_backup/github/tmp-cvs/uuu/Repository/toolchain/mkudbfs/Attic/makefile,v 1.3 2003/10/12 22:32:33 bitglue Exp $

PREFIX = /usr/local
BINDIR = $(PREFIX)/bin

.PHONY: clean install

mkudbfs: mkudbfs.c mkudbfs.h
	$(CC) -o mkudbfs $(CPPFLAGS) $(CFLAGS) mkudbfs.c

clean:
	rm -f mkudbfs

install: mkudbfs
	cp mkudbfs "$(BINDIR)"
