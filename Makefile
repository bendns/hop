.PHONY: gen build test install run clean icon

DERIVED := build
APP_NAME := Hop.app
BUILT_APP := $(DERIVED)/Build/Products/Debug/$(APP_NAME)
INSTALL_DIR := /Applications

gen:
	xcodegen generate

build: gen
	xcodebuild -project Hop.xcodeproj -scheme Hop -configuration Debug -derivedDataPath $(DERIVED) build

test: gen
	xcodebuild -project Hop.xcodeproj -scheme Hop -derivedDataPath $(DERIVED) test

install: build
	@killall Hop 2>/dev/null || true
	@test -d "$(BUILT_APP)" || (echo "Built app not found at $(BUILT_APP)"; exit 1)
	rm -rf $(INSTALL_DIR)/$(APP_NAME)
	cp -R "$(BUILT_APP)" $(INSTALL_DIR)/
	@echo "Installed to $(INSTALL_DIR)/$(APP_NAME)"

run: install
	open $(INSTALL_DIR)/$(APP_NAME)

icon:
	swift scripts/generate-icon.swift

clean:
	rm -rf Hop.xcodeproj
	rm -rf $(DERIVED)
