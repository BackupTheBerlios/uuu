.PHONY: all clean test

all: udbfslib.o

udbfslib.o: udbfslib.h udbfslib.c
	gcc -Wall -c udbfslib.c

test: udbfslib.o test.c
	gcc -Wall -o test test.c udbfslib.o

clean:
	rm -f udbfslib.o test
