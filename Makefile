APP_NAME = MenuBuddy
BUILD_DIR = .build/release
APP_BUNDLE = $(BUILD_DIR)/$(APP_NAME).app
BINARY = $(BUILD_DIR)/$(APP_NAME)
INSTALL_DIR = /Applications

.PHONY: build run install clean

build:
	swift build -c release
	@echo "Creating .app bundle..."
	@mkdir -p "$(APP_BUNDLE)/Contents/MacOS"
	@mkdir -p "$(APP_BUNDLE)/Contents/Resources"
	@cp "$(BINARY)" "$(APP_BUNDLE)/Contents/MacOS/$(APP_NAME)"
	@cp "Resources/Info.plist" "$(APP_BUNDLE)/Contents/Info.plist"
	@echo "Signing .app bundle..."
	@codesign --sign - --force --deep "$(APP_BUNDLE)"
	@echo "Build complete: $(APP_BUNDLE)"

run: build
	@echo "Launching $(APP_NAME)..."
	@open "$(APP_BUNDLE)"

install: build
	@echo "Installing to $(INSTALL_DIR)..."
	@rm -rf "$(INSTALL_DIR)/$(APP_NAME).app"
	@cp -r "$(APP_BUNDLE)" "$(INSTALL_DIR)/"
	@echo "Installed to $(INSTALL_DIR)/$(APP_NAME).app"

clean:
	swift package clean
	@rm -rf "$(BUILD_DIR)/$(APP_NAME).app"
	@echo "Clean complete"
