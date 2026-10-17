BINARY := nautilus
BIN_DIR := bin
NIM_FLAGS := -d:ssl --hints:off

.PHONY: all build run release start check fmt clean size package

all: build

build:
	nim c $(NIM_FLAGS) src/nautilus.nim

run:
	nim c -r $(NIM_FLAGS) src/nautilus.nim

release:
	nim c $(NIM_FLAGS) -d:release --opt:speed -o:$(BIN_DIR)/$(BINARY) src/nautilus.nim

start: release
	./$(BIN_DIR)/$(BINARY)

check:
	nim check $(NIM_FLAGS) src/nautilus.nim

fmt:
	nimpretty src/nautilus.nim

clean:
	rm -rf $(BIN_DIR) nimcache

size: release
	@ls -lh $(BIN_DIR)/$(BINARY) | awk '{print "Binary size:", $$5}'

package: release
	bash scripts/package.sh
