# Chips iOS/macOS App - Development Commands
# Usage: make <target>

.PHONY: help setup build test run clean lint format \
        archive testflight release cloudkit-dev cloudkit-prod \
        docs screenshots generate run-ios run-ipad run-mac \
        check-packages update-packages

# Default target
help:
	@echo "Chips Development Commands"
	@echo ""
	@echo "Setup & Build:"
	@echo "  setup          - Install dependencies and generate Xcode project"
	@echo "  generate       - Regenerate Xcode project from project.yml"
	@echo "  build          - Build for all platforms (debug)"
	@echo "  build-ios      - Build for iOS only"
	@echo "  build-mac      - Build for macOS only"
	@echo "  build-release  - Build for all platforms (release)"
	@echo "  clean          - Clean build artifacts"
	@echo ""
	@echo "Running (Simulator):"
	@echo "  run-ios        - Build and run on iPhone 15 Simulator"
	@echo "  run-ipad       - Build and run on iPad Simulator"
	@echo "  run-mac        - Build and run macOS app"
	@echo "  open           - Open project in Xcode"
	@echo ""
	@echo "Testing:"
	@echo "  test           - Run all unit tests"
	@echo "  test-ui        - Run UI tests"
	@echo "  test-coverage  - Run tests with coverage report"
	@echo ""
	@echo "Code Quality:"
	@echo "  lint           - Run SwiftLint"
	@echo "  format         - Format code with SwiftFormat"
	@echo ""
	@echo "Deployment:"
	@echo "  archive        - Create release archives for all platforms"
	@echo "  testflight     - Upload to TestFlight"
	@echo "  release        - Full release process"
	@echo ""
	@echo "CloudKit:"
	@echo "  cloudkit-dev   - Deploy schema to development"
	@echo "  cloudkit-prod  - Deploy schema to production"
	@echo ""
	@echo "Utilities:"
	@echo "  docs           - Generate documentation"
	@echo "  screenshots    - Generate App Store screenshots"
	@echo "  loc            - Count lines of code"
	@echo "  simulators     - List available simulators"
	@echo ""
	@echo "Package Management:"
	@echo "  check-packages - Check for Swift package updates"
	@echo "  update-packages - Update packages to latest versions"

# =============================================================================
# CONFIGURATION
# =============================================================================

PROJECT := Chips.xcodeproj
SCHEME_IOS := Chips-iOS
SCHEME_MACOS := Chips-macOS
BUNDLE_ID := com.chips.app

# Simulator device names - automatically detected or override with env vars
# Run 'make simulators' to see available devices
# Override: IPHONE_SIMULATOR='iPhone 16 Pro' make run-ios
IPHONE_SIMULATOR ?= $(shell ./scripts/detect-simulator.sh iphone)
IPAD_SIMULATOR ?= $(shell ./scripts/detect-simulator.sh ipad)

# =============================================================================
# SETUP & BUILD
# =============================================================================

setup: install-tools generate
	@echo "✅ Setup complete! Run 'make open' to open in Xcode"

install-tools:
	@echo "📦 Installing dependencies..."
	@which xcodegen > /dev/null || brew install xcodegen
	@which swiftlint > /dev/null || brew install swiftlint
	@which swiftformat > /dev/null || brew install swiftformat
	@which xcbeautify > /dev/null || brew install xcbeautify
	@echo "✅ Tools installed"

generate:
	@echo "🔧 Generating Xcode project..."
	xcodegen generate
	@echo "✅ Project generated"

build: generate
	@echo "🔨 Building for iOS..."
	@xcodebuild build \
		-project $(PROJECT) \
		-scheme $(SCHEME_IOS) \
		-destination 'platform=iOS Simulator,name=$(IPHONE_SIMULATOR)' \
		-quiet \
		| xcbeautify || xcodebuild build \
		-project $(PROJECT) \
		-scheme $(SCHEME_IOS) \
		-destination 'platform=iOS Simulator,name=$(IPHONE_SIMULATOR)'
	@echo "🔨 Building for macOS..."
	@xcodebuild build \
		-project $(PROJECT) \
		-scheme $(SCHEME_MACOS) \
		-destination 'platform=macOS' \
		-quiet \
		| xcbeautify || xcodebuild build \
		-project $(PROJECT) \
		-scheme $(SCHEME_MACOS) \
		-destination 'platform=macOS'
	@echo "✅ Build complete"

build-ios: generate
	@echo "🔨 Building for iOS..."
	xcodebuild build \
		-project $(PROJECT) \
		-scheme $(SCHEME_IOS) \
		-configuration Debug \
		-destination 'platform=iOS Simulator,name=$(IPHONE_SIMULATOR)' \
		| xcbeautify

build-mac: generate
	@echo "🔨 Building for macOS..."
	xcodebuild build \
		-project $(PROJECT) \
		-scheme $(SCHEME_MACOS) \
		-destination 'platform=macOS' \
		| xcbeautify

build-release: generate
	xcodebuild build \
		-project $(PROJECT) \
		-scheme $(SCHEME_IOS) \
		-configuration Release \
		-destination 'generic/platform=iOS' \
		| xcbeautify

clean:
	@echo "🧹 Cleaning..."
	@xcodebuild clean -project $(PROJECT) -scheme $(SCHEME_IOS) 2>/dev/null || true
	@xcodebuild clean -project $(PROJECT) -scheme $(SCHEME_MACOS) 2>/dev/null || true
	@rm -rf ~/Library/Developer/Xcode/DerivedData
	@rm -rf build/
	@rm -rf $(PROJECT)
	@echo "✅ Clean complete"

# =============================================================================
# RUNNING (SIMULATOR)
# =============================================================================

run-ios: generate
	@echo "📱 Building and running on $(IPHONE_SIMULATOR)..."
	@DEVICE_ID=$$(xcrun simctl list devices available | grep "$(IPHONE_SIMULATOR)" | head -1 | sed -E 's/.*\(([A-F0-9-]{36})\).*/\1/'); \
	if [ -z "$$DEVICE_ID" ]; then \
		echo "❌ Could not find simulator device: $(IPHONE_SIMULATOR)"; \
		echo "   Available devices:"; \
		xcrun simctl list devices available | grep "iPhone" | head -5; \
		exit 1; \
	fi; \
	echo "   Using device ID: $$DEVICE_ID"; \
	xcrun simctl boot "$$DEVICE_ID" 2>/dev/null || true; \
	open -a Simulator; \
	echo "🔨 Building app..."; \
	if ! xcodebuild build \
		-project $(PROJECT) \
		-scheme $(SCHEME_IOS) \
		-configuration Debug \
		-destination "platform=iOS Simulator,id=$$DEVICE_ID" \
		| xcbeautify; then \
		echo "❌ Build failed. Trying without xcbeautify..."; \
		xcodebuild build \
			-project $(PROJECT) \
			-scheme $(SCHEME_IOS) \
			-configuration Debug \
			-destination "platform=iOS Simulator,id=$$DEVICE_ID"; \
	fi; \
	echo "🚀 Launching app..."; \
	APP_PATH=$$(find ~/Library/Developer/Xcode/DerivedData -name "Chips.app" -path "*Debug-iphonesimulator*" 2>/dev/null | head -1); \
	if [ -z "$$APP_PATH" ] || [ ! -d "$$APP_PATH" ]; then \
		echo "❌ App not found, build may have failed"; \
		exit 1; \
	fi; \
	echo "📦 Installing app from $$APP_PATH..."; \
	if [ ! -f "$$APP_PATH/Info.plist" ]; then \
		echo "❌ Error: Info.plist not found in app bundle. Build may have failed."; \
		echo "   Try: make clean && make generate && make run-ios"; \
		exit 1; \
	fi; \
	BUNDLE_ID_CHECK=$$(plutil -extract CFBundleIdentifier raw "$$APP_PATH/Info.plist" 2>/dev/null); \
	if [ -z "$$BUNDLE_ID_CHECK" ]; then \
		echo "❌ Error: Bundle ID not found in Info.plist."; \
		echo "   Try: make clean && make generate && make run-ios"; \
		exit 1; \
	fi; \
	echo "   Bundle ID: $$BUNDLE_ID_CHECK"; \
	xcrun simctl install booted "$$APP_PATH" && \
	xcrun simctl launch booted $(BUNDLE_ID) || echo "Launch failed - try opening from Xcode"

run-ipad: generate
	@echo "📱 Building and running on $(IPAD_SIMULATOR)..."
	@DEVICE_ID=$$(xcrun simctl list devices available | grep "$(IPAD_SIMULATOR)" | head -1 | sed -E 's/.*\(([A-F0-9-]{36})\).*/\1/'); \
	if [ -z "$$DEVICE_ID" ]; then \
		echo "❌ Could not find simulator device: $(IPAD_SIMULATOR)"; \
		echo "   Available devices:"; \
		xcrun simctl list devices available | grep "iPad" | head -5; \
		exit 1; \
	fi; \
	echo "   Using device ID: $$DEVICE_ID"; \
	xcrun simctl boot "$$DEVICE_ID" 2>/dev/null || true; \
	open -a Simulator; \
	echo "🔨 Building app..."; \
	if ! xcodebuild build \
		-project $(PROJECT) \
		-scheme $(SCHEME_IOS) \
		-configuration Debug \
		-destination "platform=iOS Simulator,id=$$DEVICE_ID" \
		| xcbeautify; then \
		echo "❌ Build failed. Trying without xcbeautify..."; \
		xcodebuild build \
			-project $(PROJECT) \
			-scheme $(SCHEME_IOS) \
			-configuration Debug \
			-destination "platform=iOS Simulator,id=$$DEVICE_ID"; \
	fi; \
	echo "🚀 Launching app..."; \
	APP_PATH=$$(find ~/Library/Developer/Xcode/DerivedData -name "Chips.app" -path "*Debug-iphonesimulator*" 2>/dev/null | head -1); \
	if [ -z "$$APP_PATH" ] || [ ! -d "$$APP_PATH" ]; then \
		echo "❌ App not found, build may have failed"; \
		exit 1; \
	fi; \
	echo "📦 Installing app from $$APP_PATH..."; \
	if [ ! -f "$$APP_PATH/Info.plist" ]; then \
		echo "❌ Error: Info.plist not found in app bundle. Build may have failed."; \
		echo "   Try: make clean && make generate && make run-ipad"; \
		exit 1; \
	fi; \
	BUNDLE_ID_CHECK=$$(plutil -extract CFBundleIdentifier raw "$$APP_PATH/Info.plist" 2>/dev/null); \
	if [ -z "$$BUNDLE_ID_CHECK" ]; then \
		echo "❌ Error: Bundle ID not found in Info.plist."; \
		echo "   Try: make clean && make generate && make run-ipad"; \
		exit 1; \
	fi; \
	echo "   Bundle ID: $$BUNDLE_ID_CHECK"; \
	xcrun simctl install booted "$$APP_PATH" && \
	xcrun simctl launch booted $(BUNDLE_ID) || echo "Launch failed - try opening from Xcode"

run-mac: generate
	@echo "💻 Building and running on macOS..."
	xcodebuild build -project $(PROJECT) -scheme $(SCHEME_MACOS) -destination 'platform=macOS' | xcbeautify || xcodebuild build -project $(PROJECT) -scheme $(SCHEME_MACOS) -destination 'platform=macOS'
	@echo "🚀 Launching app..."
	@open $$(find ~/Library/Developer/Xcode/DerivedData -name "Chips.app" -path "*Debug/*" -not -path "*iphonesimulator*" 2>/dev/null | head -1) || echo "App not found, open Xcode to build"

open: generate
	@open $(PROJECT)

# =============================================================================
# TESTING
# =============================================================================

test: generate
	@echo "🧪 Running unit tests..."
	xcodebuild test \
		-project $(PROJECT) \
		-scheme $(SCHEME_IOS) \
		-destination 'platform=iOS Simulator,name=$(IPHONE_SIMULATOR)' \
		-only-testing:ChipsTests-iOS \
		| xcbeautify

test-ui: generate
	@echo "🧪 Running UI tests..."
	xcodebuild test \
		-project $(PROJECT) \
		-scheme $(SCHEME_IOS) \
		-destination 'platform=iOS Simulator,name=$(IPHONE_SIMULATOR)' \
		-only-testing:ChipsUITests-iOS \
		| xcbeautify

test-coverage: generate
	xcodebuild test \
		-project $(PROJECT) \
		-scheme $(SCHEME_IOS) \
		-destination 'platform=iOS Simulator,name=$(IPHONE_SIMULATOR)' \
		-enableCodeCoverage YES \
		| xcbeautify
	@xcrun xccov view --report ~/Library/Developer/Xcode/DerivedData/Chips-*/Logs/Test/*.xcresult

test-mac: generate
	xcodebuild test \
		-project $(PROJECT) \
		-scheme $(SCHEME_MACOS) \
		-destination 'platform=macOS' \
		| xcbeautify

# =============================================================================
# CODE QUALITY
# =============================================================================

lint:
	@echo "🔍 Linting..."
	swiftlint lint --config .swiftlint.yml

lint-fix:
	swiftlint lint --fix --config .swiftlint.yml

format:
	@echo "✨ Formatting..."
	swiftformat . --config .swiftformat

format-check:
	swiftformat . --lint --config .swiftformat

# =============================================================================
# DEPLOYMENT
# =============================================================================

ARCHIVE_PATH := build/archives

archive: generate
	@echo "📦 Creating iOS archive..."
	@mkdir -p $(ARCHIVE_PATH)
	xcodebuild archive \
		-project $(PROJECT) \
		-scheme $(SCHEME_IOS) \
		-destination 'generic/platform=iOS' \
		-archivePath $(ARCHIVE_PATH)/Chips-iOS.xcarchive \
		| xcbeautify
	@echo "📦 Creating macOS archive..."
	xcodebuild archive \
		-project $(PROJECT) \
		-scheme $(SCHEME_MACOS) \
		-destination 'generic/platform=macOS' \
		-archivePath $(ARCHIVE_PATH)/Chips-macOS.xcarchive \
		| xcbeautify
	@echo "✅ Archives created in $(ARCHIVE_PATH)/"

# Requires App Store Connect API key configured
testflight: archive
	@echo "🚀 Uploading to TestFlight..."
	xcodebuild -exportArchive \
		-archivePath $(ARCHIVE_PATH)/Chips-iOS.xcarchive \
		-exportPath $(ARCHIVE_PATH)/export-ios \
		-exportOptionsPlist ExportOptions-AppStore.plist
	xcrun altool --upload-app \
		-f $(ARCHIVE_PATH)/export-ios/Chips.ipa \
		-t ios \
		--apiKey $(APP_STORE_KEY_ID) \
		--apiIssuer $(APP_STORE_ISSUER_ID)

release: lint test archive
	@echo "✅ Ready for release!"
	@echo "1. Run 'make testflight' to upload"
	@echo "2. Submit for review in App Store Connect"

# =============================================================================
# CLOUDKIT
# =============================================================================

cloudkit-dev:
	@echo "☁️ Deploying CloudKit schema to Development..."
	@echo "Use Xcode: Product → Perform Action → Deploy Schema to Development"

cloudkit-prod:
	@echo "⚠️  WARNING: Deploying to Production is irreversible!"
	@read -p "Are you sure? (y/N) " confirm && [ "$$confirm" = "y" ] || exit 1
	@echo "Use Xcode: Product → Perform Action → Deploy Schema to Production"

# =============================================================================
# UTILITIES
# =============================================================================

docs: generate
	@echo "📚 Generating documentation..."
	xcodebuild docbuild \
		-project $(PROJECT) \
		-scheme $(SCHEME_MACOS) \
		-destination 'platform=macOS' \
		-derivedDataPath build/docs
	@echo "✅ Documentation generated in build/docs/"

screenshots: generate
	@echo "📸 Generating App Store screenshots..."
	xcodebuild test \
		-project $(PROJECT) \
		-scheme $(SCHEME_IOS) \
		-destination 'platform=iOS Simulator,name=iPhone 15 Pro Max' \
		-only-testing:ChipsUITests-iOS/ScreenshotTests \
		| xcbeautify
	@echo "✅ Screenshots saved to Screenshots/"

loc:
	@echo "📊 Lines of code:"
	@find . -name "*.swift" -not -path "./build/*" -not -path "./.build/*" | xargs wc -l | tail -1

simulators:
	@echo "📱 Auto-detected simulators:"
	@echo "  iPhone: $(IPHONE_SIMULATOR)"
	@echo "  iPad:   $(IPAD_SIMULATOR)"
	@echo ""
	@echo "📱 Available iPhone simulators:"
	@xcrun simctl list devices available | grep "iPhone" | head -10
	@echo ""
	@echo "📱 Available iPad simulators:"
	@xcrun simctl list devices available | grep "iPad" | head -10
	@echo ""
	@echo "To override auto-detection, run:"
	@echo "  make run-ios IPHONE_SIMULATOR='iPhone 16 Pro'"

# Watch for changes and rebuild (requires fswatch)
watch:
	@echo "👀 Watching for changes..."
	fswatch -o Chips/**/*.swift | xargs -n1 -I{} make build-ios

# =============================================================================
# PACKAGE MANAGEMENT
# =============================================================================

check-packages: generate
	@echo "📦 Checking for Swift package updates..."
	@echo ""
	@RESOLVED=$$(xcodebuild -resolvePackageDependencies -project $(PROJECT) -scheme $(SCHEME_IOS) 2>&1 | grep -A 10 "Resolved source packages" | grep "@" | sed 's/.*@ //'); \
	echo "Current versions:"; \
	echo "$$RESOLVED"; \
	echo ""; \
	echo "Checking latest versions on GitHub..."; \
	echo ""; \
	SWIFT_MARKDOWN_LATEST=$$(git ls-remote --tags https://github.com/apple/swift-markdown.git 2>/dev/null | grep -E 'refs/tags/[0-9]' | tail -1 | sed 's/.*refs\/tags\///'); \
	YAMS_LATEST=$$(git ls-remote --tags https://github.com/jpsim/Yams.git 2>/dev/null | grep -E 'refs/tags/[0-9]' | tail -1 | sed 's/.*refs\/tags\///'); \
	CMARK_LATEST=$$(git ls-remote --tags https://github.com/swiftlang/swift-cmark.git 2>/dev/null | grep -E 'refs/tags/[0-9]' | tail -1 | sed 's/.*refs\/tags\///'); \
	SWIFT_MARKDOWN_CURRENT=$$(grep -A 2 "swift-markdown:" project.yml | grep "from:" | sed 's/.*"\(.*\)"/\1/'); \
	YAMS_CURRENT=$$(grep -A 2 "^  Yams:" project.yml | grep "from:" | sed 's/.*"\(.*\)"/\1/'); \
	echo "Package Version Comparison:"; \
	echo "  swift-markdown:  $$SWIFT_MARKDOWN_CURRENT → $$SWIFT_MARKDOWN_LATEST"; \
	echo "  Yams:            $$YAMS_CURRENT → $$YAMS_LATEST"; \
	echo "  cmark-gfm:       (dependency, latest: $$CMARK_LATEST)"; \
	echo ""; \
	if [ "$$SWIFT_MARKDOWN_CURRENT" != "$$SWIFT_MARKDOWN_LATEST" ] || [ "$$YAMS_CURRENT" != "$$YAMS_LATEST" ]; then \
		echo "⚠️  Updates available! Run 'make update-packages' to update."; \
	else \
		echo "✅ All packages are up to date!"; \
	fi

update-packages: generate
	@echo "🔄 Updating Swift packages to latest versions..."
	@echo ""
	@SWIFT_MARKDOWN_LATEST=$$(git ls-remote --tags https://github.com/apple/swift-markdown.git 2>/dev/null | grep -E 'refs/tags/[0-9]' | tail -1 | sed 's/.*refs\/tags\///'); \
	YAMS_LATEST=$$(git ls-remote --tags https://github.com/jpsim/Yams.git 2>/dev/null | grep -E 'refs/tags/[0-9]' | tail -1 | sed 's/.*refs\/tags\///'); \
	SWIFT_MARKDOWN_CURRENT=$$(grep -A 2 "swift-markdown:" project.yml | grep "from:" | sed 's/.*"\(.*\)"/\1/'); \
	YAMS_CURRENT=$$(grep -A 2 "^  Yams:" project.yml | grep "from:" | sed 's/.*"\(.*\)"/\1/'); \
	if [ -z "$$SWIFT_MARKDOWN_LATEST" ] || [ -z "$$YAMS_LATEST" ]; then \
		echo "❌ Error: Could not fetch latest versions. Check your internet connection."; \
		exit 1; \
	fi; \
	echo "Updating packages:"; \
	if [ "$$SWIFT_MARKDOWN_CURRENT" != "$$SWIFT_MARKDOWN_LATEST" ]; then \
		echo "  swift-markdown: $$SWIFT_MARKDOWN_CURRENT → $$SWIFT_MARKDOWN_LATEST"; \
		sed -i '' "s/from: \"$$SWIFT_MARKDOWN_CURRENT\"/from: \"$$SWIFT_MARKDOWN_LATEST\"/" project.yml; \
	else \
		echo "  swift-markdown: $$SWIFT_MARKDOWN_CURRENT (already latest)"; \
	fi; \
	if [ "$$YAMS_CURRENT" != "$$YAMS_LATEST" ]; then \
		echo "  Yams: $$YAMS_CURRENT → $$YAMS_LATEST"; \
		sed -i '' "s/from: \"$$YAMS_CURRENT\"/from: \"$$YAMS_LATEST\"/" project.yml; \
	else \
		echo "  Yams: $$YAMS_CURRENT (already latest)"; \
	fi; \
	echo ""; \
	echo "✅ Updated project.yml"; \
	echo "🔄 Regenerating Xcode project..."; \
	make generate; \
	echo ""; \
	echo "✅ Package update complete! Run 'make check-packages' to verify."
