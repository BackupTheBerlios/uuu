# $Header: /home/xubuntu/berlios_backup/github/tmp-cvs/uuu/Repository/toolchain/udbfstools/GNUmakefile,v 1.2 2003/10/13 21:27:20 bitglue Exp $

include ../Make.conf

UTILS = udb-instboot

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
