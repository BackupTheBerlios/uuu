# $Header: /home/xubuntu/berlios_backup/github/tmp-cvs/uuu/Repository/toolchain/mkuuubimage/GNUmakefile,v 1.1 2003/11/03 14:49:39 bitglue Exp $

include ../Make.conf

.PHONY: clean install

LDFLAGS += $(ZLIB_LDFLAGS)

mkuuubimage: mkuuubimage.c
	$(compiling) '$@'
	$(CC) -o "$@" $(CPPFLAGS) $(CFLAGS) "$<" $(LDFLAGS)

clean:
	rm -f mkuuubimage

install: mkuuubimage
	$(installing) 'mkuuubimage' in '$(BINDIR)'
	cp mkuuubimage '$(BINDIR)'

-include mkuuubimage.d
