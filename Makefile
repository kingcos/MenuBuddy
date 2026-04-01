APP_NAME = MenuBuddy
BUILD_DIR = .build/release
APP_BUNDLE = $(BUILD_DIR)/$(APP_NAME).app
BINARY = $(BUILD_DIR)/$(APP_NAME)
INSTALL_DIR = /Applications

.PHONY: build run install clean dmg

build: icon
	swift build -c release
	@echo "Creating .app bundle..."
	@mkdir -p "$(APP_BUNDLE)/Contents/MacOS"
	@mkdir -p "$(APP_BUNDLE)/Contents/Resources"
	@cp "$(BINARY)" "$(APP_BUNDLE)/Contents/MacOS/$(APP_NAME)"
	@cp "Resources/Info.plist" "$(APP_BUNDLE)/Contents/Info.plist"
	@[ -f Resources/AppIcon.icns ] && cp "Resources/AppIcon.icns" "$(APP_BUNDLE)/Contents/Resources/AppIcon.icns" || true
	@for lproj in Resources/*.lproj; do cp -r "$$lproj" "$(APP_BUNDLE)/Contents/Resources/"; done
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

dmg: build
	@echo "Creating DMG..."
	@rm -f "$(BUILD_DIR)/$(APP_NAME).dmg"
	@mkdir -p "$(BUILD_DIR)/dmg-staging"
	@cp -r "$(APP_BUNDLE)" "$(BUILD_DIR)/dmg-staging/"
	@ln -sf /Applications "$(BUILD_DIR)/dmg-staging/Applications"
	@hdiutil create -volname "$(APP_NAME)" \
		-srcfolder "$(BUILD_DIR)/dmg-staging" \
		-ov -format UDZO \
		"$(BUILD_DIR)/$(APP_NAME).dmg"
	@rm -rf "$(BUILD_DIR)/dmg-staging"
	@echo "DMG created: $(BUILD_DIR)/$(APP_NAME).dmg"

clean:
	swift package clean
	@rm -rf "$(BUILD_DIR)/$(APP_NAME).app"
	@rm -f "$(BUILD_DIR)/$(APP_NAME).dmg"
	@echo "Clean complete"
