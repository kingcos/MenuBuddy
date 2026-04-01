APP_NAME = MenuBuddy
BUILD_DIR = .build/release
APP_BUNDLE = $(BUILD_DIR)/$(APP_NAME).app
BINARY = $(BUILD_DIR)/$(APP_NAME)
INSTALL_DIR = /Applications

# Code signing identity (set via environment or override on command line)
# Example: export MENUBUDDY_SIGN_IDENTITY="Developer ID Application: Name (TEAMID)"
SIGN_IDENTITY ?= $(MENUBUDDY_SIGN_IDENTITY)
# Notarytool keychain profile (created via `xcrun notarytool store-credentials`)
NOTARY_PROFILE ?= $(MENUBUDDY_NOTARY_PROFILE)

.PHONY: build build-universal run install clean dmg release

build: icon
	swift build -c release
	@$(MAKE) _bundle BINARY_SRC="$(BINARY)" CODESIGN_ID="-"

# Universal binary (arm64 + x86_64) for distribution
build-universal: icon
	swift build -c release --arch arm64 --arch x86_64
	@$(MAKE) _bundle BINARY_SRC=".build/apple/Products/Release/$(APP_NAME)" CODESIGN_ID="$(SIGN_IDENTITY)"

_bundle:
	@echo "Creating .app bundle..."
	@mkdir -p "$(APP_BUNDLE)/Contents/MacOS"
	@mkdir -p "$(APP_BUNDLE)/Contents/Resources"
	@cp "$(BINARY_SRC)" "$(APP_BUNDLE)/Contents/MacOS/$(APP_NAME)"
	@cp "Resources/Info.plist" "$(APP_BUNDLE)/Contents/Info.plist"
	@[ -f Resources/AppIcon.icns ] && cp "Resources/AppIcon.icns" "$(APP_BUNDLE)/Contents/Resources/AppIcon.icns" || true
	@for lproj in Resources/*.lproj; do cp -r "$$lproj" "$(APP_BUNDLE)/Contents/Resources/"; done
	@echo "Signing with: $(CODESIGN_ID)"
	@codesign --sign "$(CODESIGN_ID)" --force --deep --options runtime "$(APP_BUNDLE)"
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

dmg: build-universal
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

# Full release: build universal, sign, create DMG, notarize, staple
release: dmg
	@echo "Submitting for notarization..."
	xcrun notarytool submit "$(BUILD_DIR)/$(APP_NAME).dmg" \
		--keychain-profile "$(NOTARY_PROFILE)" \
		--wait
	@echo "Stapling notarization ticket..."
	xcrun stapler staple "$(BUILD_DIR)/$(APP_NAME).dmg"
	@echo ""
	@echo "=== Release ready: $(BUILD_DIR)/$(APP_NAME).dmg ==="
	@echo "Signed, notarized, and stapled. Users can install without warnings."

clean:
	swift package clean
	@rm -rf "$(BUILD_DIR)/$(APP_NAME).app"
	@rm -f "$(BUILD_DIR)/$(APP_NAME).dmg"
	@echo "Clean complete"
