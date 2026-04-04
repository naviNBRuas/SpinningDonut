BINARY := donut
SRC := src/main.asm
DIST_DIR := dist
PACKAGE_BASENAME := donut-linux-x86_64
PACKAGE_BIN := $(DIST_DIR)/$(PACKAGE_BASENAME)
PACKAGE_TAR := $(DIST_DIR)/$(PACKAGE_BASENAME).tar.gz
CHECKSUMS := $(DIST_DIR)/SHA256SUMS.txt

.PHONY: all help build run smoke-test verify workflow-test package clean distclean

all: build

help:
	@printf "Available targets:\n"
	@printf "  make build       - Build static donut binary\n"
	@printf "  make run         - Run donut renderer\n"
	@printf "  make smoke-test  - Run 1s runtime smoke-test\n"
	@printf "  make verify      - Run full validation checks\n"
	@printf "  make workflow-test - Validate CI/release workflows locally\n"
	@printf "  make package     - Build release artifacts and checksums\n"
	@printf "  make clean       - Remove build outputs\n"
	@printf "  make distclean   - Remove build and release artifacts\n"

build: $(BINARY)

$(BINARY): $(SRC)
	gcc -nostdlib -static -s -x assembler $(SRC) -o $(BINARY)

run: $(BINARY)
	./$(BINARY)

smoke-test: $(BINARY)
	timeout 1s ./$(BINARY) >/dev/null || [ $$? -eq 124 ]

verify: $(BINARY)
	bash scripts/validate.sh

workflow-test:
	bash scripts/test-workflows.sh

package: $(BINARY)
	mkdir -p $(DIST_DIR)
	cp $(BINARY) $(PACKAGE_BIN)
	tar -C $(DIST_DIR) -czf $(PACKAGE_TAR) $(PACKAGE_BASENAME)
	sha256sum $(PACKAGE_BIN) $(PACKAGE_TAR) > $(CHECKSUMS)

clean:
	rm -f $(BINARY) src/*.o

distclean: clean
	rm -rf $(DIST_DIR)
