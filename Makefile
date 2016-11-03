all: bin/wadatsumi

clean:
	@ rm -rf build bin

bin/wadatsumi: build/wadatsumi.o
	@ mkdir -p bin
	@ gcc -o $@ $^ -lSDL2 -lc

build/wadatsumi.o: build/wadatsumi.ll
	@ llc-3.8 -filetype=obj -o $@ $^

build/wadatsumi.ll: index.as
	@ mkdir -p build
	@ # TODO: Add `-o` to arrow so we can avoid this hack
	@ (arrow --compile $^ > $@ || (rm $@; exit 1)) && opt-3.8 -O3 -S -o $@ $@
