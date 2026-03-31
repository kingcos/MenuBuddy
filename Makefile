APP_NAME = MenuBuddy
BUILD_DIR = .build/release
APP_BUNDLE = $(BUILD_DIR)/$(APP_NAME).app
BINARY = $(BUILD_DIR)/$(APP_NAME)
INSTALL_DIR = /Applications

.PHONY: build run install clean

build: icon
	swift build -c release
	@echo "Creating .app bundle..."
	@mkdir -p "$(APP_BUNDLE)/Contents/MacOS"
	@mkdir -p "$(APP_BUNDLE)/Contents/Resources"
	@cp "$(BINARY)" "$(APP_BUNDLE)/Contents/MacOS/$(APP_NAME)"
	@cp "Resources/Info.plist" "$(APP_BUNDLE)/Contents/Info.plist"
	@[ -f Resources/AppIcon.icns ] && cp "Resources/AppIcon.icns" "$(APP_BUNDLE)/Contents/Resources/AppIcon.icns" || true
	@echo "Signing .app bundle..."
	@codesign --sign - --force --deep "$(APP_BUNDLE)"
	@echo "Build complete: $(APP_BUNDLE)"

icon:
	@[ -f Resources/AppIcon.icns ] || (echo "Generating app icon..." && swift Scripts/generate-icon.swift && iconutil -c icns Resources/AppIcon.iconset -o Resources/AppIcon.icns)

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
