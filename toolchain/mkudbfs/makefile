all: mkudbfs

mkudbfs: mkudbfs.h mkudbfs.c
	gcc -o mkudbfs -Wall mkudbfs.c
	strip mkudbfs

clean:
	rm -f mkudbfs

