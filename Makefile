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
	@echo "  run-mac-stdout - Build and run macOS app from terminal (see stdout/stderr)"
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
	@echo "  logo           - Generate app icons and in-app logo assets"
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
	@./scripts/clean.sh

# =============================================================================
# RUNNING (SIMULATOR)
# =============================================================================

run-ios: generate
	echo "💻 Building iOS app... with $(IPHONE_SIMULATOR)"
	@./scripts/run-ios.sh "$(IPHONE_SIMULATOR)"

run-ipad: generate
	@./scripts/run-ipad.sh "$(IPAD_SIMULATOR)"

run-mac: generate
	@./scripts/run-mac.sh

run-mac-stdout: generate
	@echo "💻 Building macOS app..."
	@set +e; \
	xcodebuild build \
		-project $(PROJECT) \
		-scheme $(SCHEME_MACOS) \
		-configuration Debug \
		-destination 'platform=macOS' \
		2>&1 | xcbeautify; \
	BUILD_EXIT=$$?; \
	set -e; \
	if [ $$BUILD_EXIT -ne 0 ]; then \
		echo "❌ Build failed with exit code $$BUILD_EXIT"; \
		exit $$BUILD_EXIT; \
	fi; \
	echo ""; \
	echo "🚀 Running app from terminal (stdout/stderr visible)..."; \
	APP_PATH=$$(find ~/Library/Developer/Xcode/DerivedData -name "Chips.app" -path "*Debug/*" -not -path "*iphonesimulator*" 2>/dev/null | head -1); \
	if [ -z "$$APP_PATH" ] || [ ! -d "$$APP_PATH" ]; then \
		echo "❌ App not found, build may have failed"; \
		exit 1; \
	fi; \
	echo "   App path: $$APP_PATH"; \
	echo ""; \
	echo "📋 App output (Ctrl+C to stop):"; \
	echo ""; \
	"$$APP_PATH/Contents/MacOS/Chips"

tail-mac-logs:
	@echo "📋 Streaming Chips app logs (Ctrl+C to stop)..."
	@log stream --predicate 'process == "Chips"' --level debug

view-logs:
	@./scripts/view-logs.sh

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

logo:
	@./scripts/generate-logo.sh

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
	@./scripts/check-packages.sh

update-packages: generate
	@./scripts/update-packages.sh
