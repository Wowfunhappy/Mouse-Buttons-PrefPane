# Makefile for Mouse Buttons Preference Pane
# Builds without Xcode

CC = clang
CFLAGS = -mmacosx-version-min=10.8 -arch x86_64 -O2 -fomit-frame-pointer
OBJCFLAGS = $(CFLAGS) -fobjc-arc -fmodules
LDFLAGS = -framework Cocoa -framework PreferencePanes -framework ApplicationServices -framework ServiceManagement

# Version (automatically set to current date)
VERSION = $(shell date +%Y.%m.%d)

# Paths
BUILD_DIR = build
BUNDLE_NAME = MouseButtons.prefPane
BUNDLE_DIR = $(BUILD_DIR)/$(BUNDLE_NAME)
CONTENTS_DIR = $(BUNDLE_DIR)/Contents
MACOS_DIR = $(CONTENTS_DIR)/MacOS
RESOURCES_DIR = $(CONTENTS_DIR)/Resources

# Source files
PREFPANE_SRCS = src/MouseSideButtonsPane.m
HELPER_SRCS = src/MouseSideButtonsHelper.m src/TouchEvents.c

# Targets
all: bundle

bundle: prefpane helper
	@echo "Creating preference pane bundle..."
	@mkdir -p $(MACOS_DIR)
	@mkdir -p $(RESOURCES_DIR)/English.lproj
	@mkdir -p $(RESOURCES_DIR)/Scripts
	
	# Copy Info.plist with updated version
	@sed -e 's/<string>1.0<\/string>/<string>$(VERSION)<\/string>/g' Resources/Info.plist > $(CONTENTS_DIR)/Info.plist
	
	# Copy PNG icon for preference pane (preferred for prefpanes)
	@if [ -f Resources/MouseSideButtons.png ]; then \
		cp Resources/MouseSideButtons.png $(RESOURCES_DIR)/MouseSideButtons.png; \
	else \
		echo "Warning: PNG icon not found for preference pane"; \
	fi
	
	# Copy preference pane binary
	@cp $(BUILD_DIR)/MouseSideButtons $(MACOS_DIR)/
	
	# Create helper app bundle with nice name
	@mkdir -p "$(MACOS_DIR)/Mouse Buttons.app/Contents/MacOS"
	@mkdir -p "$(MACOS_DIR)/Mouse Buttons.app/Contents/Resources"
	@cp Resources/MouseSideButtonsHelper-Info.plist "$(MACOS_DIR)/Mouse Buttons.app/Contents/Info.plist"
	@cp $(BUILD_DIR)/MouseSideButtonsHelper "$(MACOS_DIR)/Mouse Buttons.app/Contents/MacOS/"
	
	# Copy ICNS icon for helper app (required for macOS apps)
	@if [ -f Resources/MouseSideButtons.icns ]; then \
		cp Resources/MouseSideButtons.icns "$(MACOS_DIR)/Mouse Buttons.app/Contents/Resources/MouseSideButtons.icns"; \
	else \
		echo "Warning: ICNS icon not found for helper app"; \
	fi
	
	# Copy scripts
	@cp Resources/Scripts/* $(RESOURCES_DIR)/Scripts/ 2>/dev/null || true
	
	@echo "Bundle created at $(BUNDLE_DIR)"

prefpane: $(BUILD_DIR)/MouseSideButtons

helper: $(BUILD_DIR)/MouseSideButtonsHelper

$(BUILD_DIR)/MouseSideButtons: $(PREFPANE_SRCS)
	@echo "Building preference pane..."
	@mkdir -p $(BUILD_DIR)
	$(CC) $(OBJCFLAGS) $(LDFLAGS) -bundle -o $@ $^

$(BUILD_DIR)/MouseSideButtonsHelper: $(HELPER_SRCS)
	@echo "Building helper application..."
	@mkdir -p $(BUILD_DIR)
	$(CC) $(OBJCFLAGS) $(LDFLAGS) -o $@ $^

install: bundle
	@echo "Installing preference pane..."
	@mkdir -p ~/Library/PreferencePanes
	@rm -rf ~/Library/PreferencePanes/$(BUNDLE_NAME)
	@cp -R $(BUNDLE_DIR) ~/Library/PreferencePanes/
	
	@echo "Installing LaunchAgent..."
	@mkdir -p ~/Library/LaunchAgents
	@sed 's|/Users/USERNAME|$(HOME)|g' Resources/Wowfunhappy.sidebuttons.helper.plist > ~/Library/LaunchAgents/Wowfunhappy.sidebuttons.helper.plist
	
	@echo "Installation complete!"
	@echo "Please open System Preferences to use Mouse Buttons"

uninstall:
	@echo "Uninstalling..."
	@launchctl unload ~/Library/LaunchAgents/Wowfunhappy.sidebuttons.helper.plist 2>/dev/null || true
	@rm -rf ~/Library/PreferencePanes/$(BUNDLE_NAME)
	@rm -f ~/Library/LaunchAgents/Wowfunhappy.sidebuttons.helper.plist
	@defaults delete Wowfunhappy.sidebuttons.prefpane 2>/dev/null || true
	@echo "Uninstall complete!"

clean:
	@echo "Cleaning build files..."
	@rm -rf $(BUILD_DIR)

.PHONY: all bundle prefpane helper install uninstall clean