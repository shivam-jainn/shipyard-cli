BINARY_NAME := shipyard
CMD_DIR := ./cmd/shipyard
BIN_DIR := bin

# Platform / Architecture configuration (defaults to host arch/os)
GOOS ?= $(shell go env GOOS)
GOARCH ?= $(shell go env GOARCH)

.PHONY: all init build install test clean help

all: build

## init: Download dependencies and verify toolchain
init:
	go mod download
	go mod verify
	go mod tidy

VERSION ?= $(shell echo $${SHIPYARD_VERSION:-alpha 0.0.1})
LDFLAGS := -X 'github.com/shivam-jainn/shipyard-cli/cmd/cmdline.Version=$(VERSION)'

## build: Build hardened, stripped binary (removes symbols, debug DWARF, and local paths)
build:
	mkdir -p $(BIN_DIR)
	GOOS=$(GOOS) GOARCH=$(GOARCH) go build -trimpath -ldflags="-s -w -buildid= $(LDFLAGS)" -o $(BIN_DIR)/$(BINARY_NAME) $(CMD_DIR)/main.go

# Installation directory: default to GOPATH/bin or /opt/homebrew/bin if in PATH
GOPATH_BIN := $(shell go env GOBIN)
ifeq ($(GOPATH_BIN),)
GOPATH_BIN := $(shell go env GOPATH)/bin
endif
INSTALL_DIR ?= $(if $(shell [ -d /opt/homebrew/bin ] && [ -w /opt/homebrew/bin ] && echo 1),/opt/homebrew/bin,$(GOPATH_BIN))

## install: Install shipyard binary to system path (INSTALL_DIR or GOPATH/bin)
install: build
	mkdir -p $(INSTALL_DIR)
	cp $(BIN_DIR)/$(BINARY_NAME) $(INSTALL_DIR)/$(BINARY_NAME)
	@echo "Installed $(BINARY_NAME) to $(INSTALL_DIR)/$(BINARY_NAME)"


## test: Run unit and integration tests
test:
	go test -v ./...

## clean: Remove built binaries and artifacts
clean:
	rm -rf $(BIN_DIR)

## help: Show available make targets
help:
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@echo "  init      Download and verify dependencies for development"
	@echo "  build     Build shipyard binary to bin/ (supports GOOS=... GOARCH=...)"
	@echo "  install   Install shipyard to \$$GOBIN / \$$GOPATH/bin for global CLI access"
	@echo "  test      Run test suite"
	@echo "  clean     Remove build artifacts"
	@echo "  help      Show this help message"