# $Header: /home/xubuntu/berlios_backup/github/tmp-cvs/uuu/Repository/uuu/uuudoc/GNUmakefile,v 1.1 2004/01/01 02:17:46 bitglue Exp $

UUUROOT=..

all: uuudoc.html

include $(UUUROOT)/Make.config
include $(UUUROOT)/sourcefiles

uuudoc.xml: $(SOURCEFILES)
	$(generating) '$@'
	./extractuuudoc.pl `find '$(UUUROOT)' -name '*.asm'` > "$@"

uuudoc.html: xhtml.xsl uuudoc.xml
	$(generating) '$@'
	$(XSLTPROC) $^ > '$@'

.PHONY: clean
clean:
	rm -f uuudoc.xml uuudoc.html
