# Test Suite Makefile

.PHONY: all test unit test-ipxe clean help

all: test

test: unit test-ipxe

unit:
	@echo "Running unit tests..."
	./unit-test-driver.sh

test-ipxe:
	@echo "Running iPXE boot tests..."
	./test-ipxe-boot.sh all

clean:
	@echo "Cleaning test artifacts..."
	rm -rf /tmp/ipxe-tests

help:
	@echo "iPXE Test Suite"
	@echo "==============="
	@echo "Targets:"
	@echo "  make all    - Run all tests"
	@echo "  make unit   - Run unit tests"
	@echo "  make test-ipxe - Run iPXE boot tests"
	@echo "  make clean  - Clean test artifacts"
	@echo ""
	@echo "Note: Tests run directly on hardware/VM, no Docker required"