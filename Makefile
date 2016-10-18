all: bin/wadatsumi

clean:
	@ rm -rf build bin

bin/wadatsumi: build/wadatsumi.o
	@ mkdir -p bin
	@ gcc -o $@ $^

build/wadatsumi.o: build/wadatsumi.ll
	@ llc-3.8 -filetype=obj -o $@ $^
	@ llc-3.8 -filetype=asm -o build/wadatsumi.as $^

build/wadatsumi.ll: index.as
	@ mkdir -p build
	@ arrow --compile $^ > $@
