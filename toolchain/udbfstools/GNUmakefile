# $Header: /home/xubuntu/berlios_backup/github/tmp-cvs/uuu/Repository/toolchain/udbfstools/GNUmakefile,v 1.1 2003/10/13 01:04:58 bitglue Exp $

PREFIX = /usr/local
BINDIR = $(PREFIX)/bin

UTILS = udb-instboot

UDBFSLIB_INCLUDES =
UDBFSLIB_LIBRARIES =

CPPFLAGS += $(addprefix -I,$(UDBFSLIB_INCLUDES))
LDFLAGS += $(addprefix -L,$(UDBFSLIB_LIBRARIES)) -ludbfs

.PHONY: all
all: $(UTILS)

%: %.c
	$(CC) $(CPPFLAGS) $(CFLAGS) -o $@ $< $(LDFLAGS)

.PHONY: clean
clean:
	rm -f $(UTILS)

.PHONY: install
install: $(UTILS)
	cp $(UTILS) "$(BINDIR)"
