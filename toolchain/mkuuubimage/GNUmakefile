# $Header: /home/xubuntu/berlios_backup/github/tmp-cvs/uuu/Repository/toolchain/mkuuubimage/GNUmakefile,v 1.2 2003/11/08 19:01:00 bitglue Exp $

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
	strip '$(BINDIR)/mkuuubimage'

-include mkuuubimage.d
