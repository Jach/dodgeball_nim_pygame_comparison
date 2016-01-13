CC=nim
CFLAGS=-d:release

build:
	nim c -r *.nim

release:
	nim c -d:release *.nim 
