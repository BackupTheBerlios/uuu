# $Header: /home/xubuntu/berlios_backup/github/tmp-cvs/uuu/Repository/toolchain/udbfstools/GNUmakefile,v 1.5 2003/10/27 00:27:44 bitglue Exp $

include ../Make.conf

UTILS = udb-instboot

CPPFLAGS += $(addprefix -I,$(UDBFSLIB_INCLUDES))
LDFLAGS += $(addprefix -L,$(UDBFSLIB_LIBRARIES)) -ludbfs

.PHONY: all
all: $(UTILS)

%: %.c
	$(compiling) '$@'
	$(CC) $(CPPFLAGS) $(CFLAGS) -o $@ $< $(LDFLAGS)

.PHONY: clean
clean:
	rm -f $(UTILS) *.d

.PHONY: install
install: $(UTILS)
	$(installing) '$(UTILS)' in '$(BINDIR)'
	cp $(UTILS) '$(BINDIR)'

-include udb-instboot.d
