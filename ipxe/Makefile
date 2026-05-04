# Custom iPXE build for SFC 40G network support

# iPXE source
IPXE_URL = https://git.ipxe.org/ipxe/ipxe.git
IPXE_DIR = ipxe-source
IPXE_OUTPUT = ipxe-custom

# Configuration options
IPXE_CONFIG = CONFIG_VENDORDIR=ipxe/overrides CONFIG_NET_SFC=y CONFIG_NET_TLS=y CONFIG_NET_HTTP=y

# Target selection (choose one):
#   - iPXE with full networking stack: bin-x86_64-efi/ipxe.efi
#   - iPXE with TFTP only: bin-x86_64-efi/ipxe.trunk
#   - iPXE with HTTP only: bin-x86_64-efi/ipxe.http
#   - iPXE with all protocols: bin-x86_64-efi/ipxe.usb

.PHONY: all clean download build test

all: download build

download:
	@echo "Downloading iPXE source..."
	@if [ ! -d $(IPXE_DIR) ]; then \
		git clone $(IPXE_URL) $(IPXE_DIR); \
	else \
		echo "iPXE source already exists, updating..."; \
		cd $(IPXE_DIR) && git pull; \
	fi

build: download
	@echo "Building custom iPXE with SFC support..."
	@cd $(IPXE_DIR) && \
		make $(IPXE_CONFIG) bin-x86_64-efi/ipxe.efi

test:
	@echo "Testing iPXE..."
	@if [ -f $(IPXE_DIR)/bin-x86_64-efi/ipxe.efi ]; then \
		echo "iPXE built successfully!"; \
		ls -lh $(IPXE_DIR)/bin-x86_64-efi/ipxe.efi; \
	else \
		echo "iPXE not found. Run 'make build' first."; \
	fi

clean:
	@echo "Cleaning iPXE build..."
	@cd $(IPXE_DIR) && make clean
	@rm -f $(IPXE_OUTPUT)/ipxe.efi

install: build
	@echo "Installing iPXE..."
	@mkdir -p $(IPXE_OUTPUT)
	@cp $(IPXE_DIR)/bin-x86_64-efi/ipxe.efi $(IPXE_OUTPUT)/
	@echo "iPXE installed to $(IPXE_OUTPUT)/"

help:
	@echo "iPXE Build System"
	@echo "=================="
	@echo "Targets:"
	@echo "  make all    - Download and build iPXE"
	@echo "  make build  - Build iPXE"
	@echo "  make clean  - Remove build artifacts"
	@echo "  make test   - Verify build output"
	@echo "  make install - Install to output directory"
	@echo ""
	@echo "Note: Choose protocol support by modifying IPXE_CONFIG in Makefile"