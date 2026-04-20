.PHONY: gen build test install run clean icon

DERIVED := $(HOME)/Library/Developer/Xcode/DerivedData
APP_NAME := Hop.app
BUILT_APP := $(shell find $(DERIVED) -maxdepth 5 -type d -name $(APP_NAME) -path "*Hop-*/Build/Products/Debug/*" 2>/dev/null | head -1)
INSTALL_DIR := /Applications

gen:
	xcodegen generate

build: gen
	xcodebuild -project Hop.xcodeproj -scheme Hop -configuration Debug build

test: gen
	xcodebuild -project Hop.xcodeproj -scheme Hop test

install: build
	@killall Hop 2>/dev/null || true
	@test -n "$(BUILT_APP)" || (echo "Built app not found under $(DERIVED)"; exit 1)
	rm -rf $(INSTALL_DIR)/$(APP_NAME)
	cp -R "$(BUILT_APP)" $(INSTALL_DIR)/
	@echo "Installed to $(INSTALL_DIR)/$(APP_NAME)"

run: install
	open $(INSTALL_DIR)/$(APP_NAME)

icon:
	swift scripts/generate-icon.swift

clean:
	rm -rf Hop.xcodeproj
	rm -rf $(DERIVED)/Hop-*
