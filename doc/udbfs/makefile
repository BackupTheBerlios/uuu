DOC = udbfs
SRC = udbfs.sgml

.PHONY: all pdf dvi ps html rtf slides clean

all: pdf ps html rtf slides dvi

pdf: $(DOC).pdf
dvi: $(DOC).dvi
ps:  $(DOC).ps
html: $(DOC).html
rtf: $(DOC).rtf

$(DOC).pdf: $(SRC) makefile
	db2pdf $(SRC)

$(DOC).dvi: $(SRC) makefile
	db2dvi $(SRC)

$(DOC).ps: $(SRC) makefile
	db2ps $(SRC)

$(DOC).html: $(SRC) makefile
	db2html -u $(SRC) > /dev/null
	mv $(DOC)/$(DOC).html .
	rm -rf $(DOC) $(DOC).junk

$(DOC).rtf: $(SRC) makefile
	db2rtf $(SRC)

slides: $(SRC) makefile
	db2html $(SRC) -o slides
	rm -rf $(DOC).junk

clean:
	rm -rf $(DOC) $(DOC).pdf $(DOC).ps $(DOC).rtf $(DOC).dvi $(DOC).html
