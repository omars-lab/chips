# Chips - iOS/macOS App Specification

> A markdown-powered activity tracker with interactive chips for managing recurring tasks like workout videos.

---

## 1. Product Overview

### 1.1 Core Concept
Chips renders markdown files containing lists where each list item becomes an interactive "chip". Users can:
- Click chips to trigger actions (open URLs, start timers, launch apps)
- Track every interaction automatically
- Mark chips as complete when done with recurring activities
- View full history of interactions per chip and globally

### 1.2 Target Platforms (Day One)
- **iPhone** (iOS 17+)
- **iPad** (iPadOS 17+)
- **Mac** (macOS 14+ via SwiftUI native)

### 1.3 Key Use Case
Treadmill workout videos: User has markdown lists of YouTube videos. Each chip represents a video. Clicking opens the video, automatically logs the interaction. User may watch same video multiple times. When finished with that video forever, mark it complete (strikethrough).

---

## 2. Architecture

### 2.1 Technology Stack
```
┌─────────────────────────────────────────────────────────┐
│                      SwiftUI Views                       │
├─────────────────────────────────────────────────────────┤
│                    View Models (MVVM)                    │
├─────────────────────────────────────────────────────────┤
│  Markdown Parser  │  Action Engine  │  History Tracker  │
├─────────────────────────────────────────────────────────┤
│                 Core Data + CloudKit                     │
│              (NSPersistentCloudKitContainer)             │
├─────────────────────────────────────────────────────────┤
│     iCloud Drive      │        CloudKit Database         │
│   (Markdown Source)   │    (Tracking & Metadata Sync)    │
└─────────────────────────────────────────────────────────┘
```

### 2.2 Data Flow
1. **Import**: User points app to iCloud Drive folder containing `.md` files
2. **Parse**: App watches folder, parses markdown into chip collections
3. **Render**: Chips displayed in scrollable views, organized by file/section
4. **Interact**: Taps trigger actions + automatic tracking
5. **Sync**: All interaction data syncs via CloudKit across devices

### 2.3 CloudKit Schema

```swift
// CKRecord Types

ChipSource {
    id: UUID
    name: String              // File name
    iCloudPath: String        // Path in iCloud Drive
    lastParsed: Date
    checksum: String          // Detect file changes
}

Chip {
    id: UUID
    sourceID: UUID            // FK to ChipSource
    title: String
    rawMarkdown: String
    actionType: String        // "url", "timer", "app", "custom"
    actionPayload: String     // JSON with action details
    metadata: String          // JSON from frontmatter/inline tags
    sortOrder: Int
    isCompleted: Bool
    completedAt: Date?
}

ChipInteraction {
    id: UUID
    chipID: UUID              // FK to Chip
    timestamp: Date
    actionTaken: String       // What action was triggered
    duration: Int?            // For timer actions (seconds)
    notes: String?            // User-added notes
    deviceName: String        // Which device
}
```

---

## 3. Features

### 3.1 Markdown Parsing

#### Supported Syntax
```markdown
---
title: Treadmill Workouts
category: fitness
default_action: url
---

# Cardio Videos

- [30 Min HIIT](https://youtube.com/watch?v=xxx) @timer @app:youtube
- [Walking Workout](https://youtube.com/watch?v=yyy) #beginner
- [ ] New video to try
- [x] ~~Completed video~~

## Strength Training

1. [Upper Body](https://youtube.com/watch?v=zzz) @duration:45m
2. [Core Workout](https://youtube.com/watch?v=aaa)
```

#### Inline Tags (Extended Syntax)
| Tag | Purpose | Example |
|-----|---------|---------|
| `@timer` | Enable timer tracking | `- Video @timer` |
| `@app:name` | Open in specific app | `@app:youtube` |
| `@duration:Xm` | Expected duration | `@duration:30m` |
| `#tag` | Categorization | `#beginner #cardio` |
| `@repeat:X` | Suggested repeat count | `@repeat:5` |

#### Frontmatter Support
```yaml
---
title: Display name for the file
category: Grouping category
default_action: url | timer | app
default_app: youtube
---
```

### 3.2 Chip UI Component

```
┌─────────────────────────────────────────────────┐
│  ▶️  30 Min HIIT Workout              ⏱️ 3x    │
│      #cardio #intermediate                      │
└─────────────────────────────────────────────────┘
     │              │                    │
     │              │                    └─ Interaction count
     │              └─ Tags
     └─ Action indicator (▶️=video, ⏱️=timer, 🔗=link)
```

**States:**
- **Default**: Normal appearance
- **In Progress**: Highlighted border, timer visible if active
- **Completed**: Strikethrough, muted colors

**Interactions:**
- **Tap**: Execute primary action + log interaction
- **Long Press**: Context menu (view history, add note, mark complete)
- **Swipe Right**: Quick-complete
- **Swipe Left**: View recent interactions

### 3.3 Action Types

#### URL Action
```swift
struct URLAction {
    let url: URL
    let preferredApp: String?  // "youtube", "safari", "vlc"

    func execute() {
        // Try preferred app first, fall back to system default
    }
}
```

#### Timer Action
```swift
struct TimerAction {
    let expectedDuration: TimeInterval?
    var elapsedTime: TimeInterval = 0
    var isRunning: Bool = false

    // Timer continues even if app backgrounded
    // Uses background tasks + local notifications
}
```

#### Open in App Action
Supported apps (initial):
- YouTube
- Safari
- VLC
- Music
- Podcasts
- Custom URL schemes

### 3.4 History & Tracking

#### Global History Tab
- Chronological list of all interactions
- Filter by: date range, chip, action type, device
- Statistics: total interactions, streaks, time spent

#### Per-Chip History
- Access via long-press → "View History"
- Shows: all interactions, notes, total count, first/last access
- Edit: add notes to past interactions, correct timestamps

### 3.5 iCloud Drive Integration

```swift
class MarkdownSourceManager {
    // Monitor selected folder for changes
    let folderURL: URL  // iCloud Drive path

    func startMonitoring() {
        // Use NSMetadataQuery for iCloud changes
        // Re-parse changed files
        // Preserve chip IDs across re-parses (match by content hash)
    }

    func selectFolder() {
        // UIDocumentPickerViewController / NSOpenPanel
    }
}
```

---

## 4. User Interface

### 4.1 App Structure

```
┌─────────────────────────────────────────────────────────┐
│  Tab Bar (iPhone) / Sidebar (iPad/Mac)                  │
├─────────────────────────────────────────────────────────┤
│  📋 Chips     │  📊 History  │  ⚙️ Settings             │
└─────────────────────────────────────────────────────────┘
```

### 4.2 Chips Tab
- **Source Selector**: Dropdown/picker to switch between markdown files
- **Chip Grid/List**: Adaptive layout (list on iPhone, grid on iPad/Mac)
- **Section Headers**: From markdown `#` headers
- **Filter Bar**: Quick filters by tag, completion status
- **Active Timer**: Floating indicator if timer running

### 4.3 History Tab
- **Timeline View**: Grouped by day
- **Stats Cards**: This week's activity, streaks, most-used chips
- **Search**: Full-text search across interactions and notes

### 4.4 Settings Tab
- **Sources**: Manage markdown file sources
- **Appearance**: Theme, chip size, layout preferences
- **Actions**: Configure default apps, timer behavior
- **Sync**: CloudKit sync status, force refresh
- **Export**: Export history as JSON/CSV

### 4.5 Platform Adaptations

| Feature | iPhone | iPad | Mac |
|---------|--------|------|-----|
| Navigation | Tab bar | Sidebar | Sidebar |
| Chip layout | List | Grid | Grid |
| Timer | Floating pill | Picture-in-picture | Menu bar extra |
| Quick actions | Swipe gestures | Context menu | Right-click menu |

---

## 5. Implementation Plan

### Phase 1: Foundation
1. **Project Setup**
   - Create Xcode project (SwiftUI, multiplatform)
   - Configure CloudKit container
   - Set up Core Data with CloudKit sync
   - Create basic app structure (tabs, navigation)

2. **Data Models**
   - Define Core Data entities (ChipSource, Chip, ChipInteraction)
   - Create CloudKit schema
   - Build repository layer

### Phase 2: Markdown Engine
3. **Parser Development**
   - Integrate markdown parsing library (swift-markdown or custom)
   - Implement frontmatter parsing
   - Build inline tag extractor
   - Handle task list syntax

4. **iCloud Drive Integration**
   - Folder picker UI
   - File monitoring with NSMetadataQuery
   - Change detection and re-parsing
   - Chip ID preservation logic

### Phase 3: Core UI
5. **Chip Components**
   - Design chip view component
   - Implement all visual states
   - Build gesture handlers
   - Create context menu

6. **Main Views**
   - Chips tab with source selector
   - Section-based layout
   - Filter and sort controls
   - Platform-specific layouts

### Phase 4: Actions & Tracking
7. **Action Engine**
   - URL action with app routing
   - Timer action with background support
   - Interaction logging
   - Notes attachment

8. **History System**
   - History tab UI
   - Per-chip history view
   - Statistics calculations
   - Search implementation

### Phase 5: Polish & Sync
9. **CloudKit Sync**
   - Test cross-device sync
   - Conflict resolution
   - Offline support
   - Sync status UI

10. **Platform Polish**
    - iPad sidebar navigation
    - Mac menu bar integration
    - Keyboard shortcuts (Mac)
    - Widget (iOS/iPadOS)

---

## 6. Testing Strategy

### 6.1 Unit Tests
```swift
// Core logic to test:
- MarkdownParser: Parse various markdown formats
- TagExtractor: Extract inline tags correctly
- ChipMatcher: Match chips across file changes
- ActionRouter: Route to correct app/handler
- InteractionTracker: Log interactions correctly
```

### 6.2 Integration Tests
```swift
// End-to-end flows:
- Import markdown file → chips appear
- Tap chip → action executes + logged
- Mark complete → syncs to other devices
- File changes → chips update, history preserved
```

### 6.3 UI Tests
```swift
// User flows:
- Onboarding: Select folder, first file parse
- Daily use: Open app, tap chips, view history
- Management: Complete chips, add notes
```

### 6.4 CloudKit Testing
- Use separate development container
- Test with multiple simulators
- Test offline → online sync
- Test conflict scenarios

---

## 7. Deployment Plan

### 7.1 Local Development
```bash
# Prerequisites
- Xcode 15+
- Apple Developer account (for CloudKit)
- Real device recommended for full testing

# Setup
1. Clone repository
2. Open Chips.xcodeproj
3. Configure signing & CloudKit container
4. Build and run
```

### 7.2 TestFlight (Internal Testing)
```bash
# Steps:
1. Archive build in Xcode
2. Upload to App Store Connect
3. Add internal testers (up to 100)
4. Distribute via TestFlight app

# Timeline:
- Internal: Same-day approval
- Test for 1-2 weeks minimum
```

### 7.3 TestFlight (External Beta)
```bash
# Steps:
1. Submit for Beta App Review
2. Add external testers (up to 10,000)
3. Collect feedback via TestFlight

# Timeline:
- Review: 24-48 hours typically
- Beta period: 2-4 weeks recommended
```

### 7.4 App Store Release
```bash
# Checklist:
- [ ] App Store screenshots (all device sizes)
- [ ] App description and keywords
- [ ] Privacy policy URL
- [ ] Support URL
- [ ] Age rating questionnaire
- [ ] Pricing (Free with no IAP initially)

# Review timeline: 24-48 hours typically
```

### 7.5 CloudKit Production
```bash
# Before release:
1. Deploy schema to Production in CloudKit Dashboard
2. Verify indexes and permissions
3. Test with production container
4. Cannot modify schema after users have data!
```

---

## 8. File Structure

```
Chips/
├── App/
│   ├── ChipsApp.swift              # App entry point
│   └── ContentView.swift           # Root view with tab/sidebar
│
├── Models/
│   ├── Chip.swift                  # Core Data entity
│   ├── ChipSource.swift            # Core Data entity
│   ├── ChipInteraction.swift       # Core Data entity
│   └── Chips.xcdatamodeld          # Core Data model
│
├── Services/
│   ├── MarkdownParser/
│   │   ├── MarkdownParser.swift    # Main parser
│   │   ├── FrontmatterParser.swift # YAML frontmatter
│   │   └── TagExtractor.swift      # Inline tag extraction
│   │
│   ├── CloudKit/
│   │   ├── PersistenceController.swift  # Core Data + CloudKit
│   │   └── SyncMonitor.swift            # Sync status tracking
│   │
│   ├── Actions/
│   │   ├── ActionEngine.swift      # Action dispatcher
│   │   ├── URLAction.swift
│   │   ├── TimerAction.swift
│   │   └── AppLauncher.swift       # Open in specific apps
│   │
│   └── SourceManager/
│       └── MarkdownSourceManager.swift  # iCloud Drive monitoring
│
├── ViewModels/
│   ├── ChipsViewModel.swift
│   ├── HistoryViewModel.swift
│   └── SettingsViewModel.swift
│
├── Views/
│   ├── Chips/
│   │   ├── ChipsTabView.swift
│   │   ├── ChipView.swift          # Single chip component
│   │   ├── ChipGridView.swift
│   │   └── ChipContextMenu.swift
│   │
│   ├── History/
│   │   ├── HistoryTabView.swift
│   │   ├── InteractionRow.swift
│   │   └── StatsCardView.swift
│   │
│   ├── Settings/
│   │   ├── SettingsTabView.swift
│   │   ├── SourcesSettingsView.swift
│   │   └── SyncStatusView.swift
│   │
│   └── Shared/
│       ├── TimerFloatingView.swift
│       └── FilterBarView.swift
│
├── Utilities/
│   ├── Extensions/
│   └── Constants.swift
│
└── Resources/
    ├── Assets.xcassets
    └── Localizable.strings
```

---

## 9. Makefile (Development Commands)

Keep a `Makefile` at the project root with all important commands as targets. This serves as living documentation and ensures consistent commands across the team.

```makefile
# Chips iOS/macOS App - Development Commands
# Usage: make <target>

.PHONY: help setup build test run clean lint format \
        archive testflight release cloudkit-dev cloudkit-prod \
        docs screenshots

# Default target
help:
	@echo "Chips Development Commands"
	@echo ""
	@echo "Setup & Build:"
	@echo "  setup          - Install dependencies and configure project"
	@echo "  build          - Build for all platforms (debug)"
	@echo "  build-release  - Build for all platforms (release)"
	@echo "  clean          - Clean build artifacts"
	@echo ""
	@echo "Testing:"
	@echo "  test           - Run all unit tests"
	@echo "  test-ui        - Run UI tests"
	@echo "  test-coverage  - Run tests with coverage report"
	@echo ""
	@echo "Running:"
	@echo "  run-ios        - Run on iOS Simulator"
	@echo "  run-ipad       - Run on iPad Simulator"
	@echo "  run-mac        - Run macOS app"
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

# =============================================================================
# SETUP & BUILD
# =============================================================================

PROJECT := Chips.xcodeproj
SCHEME := Chips

setup:
	@echo "Installing dependencies..."
	brew install swiftlint swiftformat xcbeautify || true
	@echo "Resolving Swift packages..."
	xcodebuild -resolvePackageDependencies -project $(PROJECT)
	@echo "Setup complete!"

build:
	@echo "Building for all platforms (debug)..."
	xcodebuild build \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-destination 'platform=iOS Simulator,name=iPhone 15' \
		| xcbeautify
	xcodebuild build \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-destination 'platform=macOS' \
		| xcbeautify

build-release:
	xcodebuild build \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-configuration Release \
		-destination 'generic/platform=iOS' \
		| xcbeautify

clean:
	xcodebuild clean -project $(PROJECT) -scheme $(SCHEME)
	rm -rf ~/Library/Developer/Xcode/DerivedData/Chips-*
	rm -rf build/

# =============================================================================
# TESTING
# =============================================================================

test:
	@echo "Running unit tests..."
	xcodebuild test \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-destination 'platform=iOS Simulator,name=iPhone 15' \
		-only-testing:ChipsTests \
		| xcbeautify

test-ui:
	@echo "Running UI tests..."
	xcodebuild test \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-destination 'platform=iOS Simulator,name=iPhone 15' \
		-only-testing:ChipsUITests \
		| xcbeautify

test-coverage:
	xcodebuild test \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-destination 'platform=iOS Simulator,name=iPhone 15' \
		-enableCodeCoverage YES \
		| xcbeautify
	xcrun xccov view --report ~/Library/Developer/Xcode/DerivedData/Chips-*/Logs/Test/*.xcresult

test-mac:
	xcodebuild test \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-destination 'platform=macOS' \
		| xcbeautify

# =============================================================================
# RUNNING
# =============================================================================

run-ios:
	xcodebuild build \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-destination 'platform=iOS Simulator,name=iPhone 15'
	xcrun simctl boot "iPhone 15" 2>/dev/null || true
	xcrun simctl launch booted com.yourcompany.Chips

run-ipad:
	xcodebuild build \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-destination 'platform=iOS Simulator,name=iPad Pro (12.9-inch) (6th generation)'
	xcrun simctl boot "iPad Pro (12.9-inch) (6th generation)" 2>/dev/null || true
	open -a Simulator

run-mac:
	xcodebuild build \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-destination 'platform=macOS'
	open ~/Library/Developer/Xcode/DerivedData/Chips-*/Build/Products/Debug/Chips.app

# =============================================================================
# CODE QUALITY
# =============================================================================

lint:
	swiftlint lint --config .swiftlint.yml

lint-fix:
	swiftlint lint --fix --config .swiftlint.yml

format:
	swiftformat . --config .swiftformat

format-check:
	swiftformat . --lint --config .swiftformat

# =============================================================================
# DEPLOYMENT
# =============================================================================

ARCHIVE_PATH := build/archives

archive:
	@echo "Creating iOS archive..."
	xcodebuild archive \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-destination 'generic/platform=iOS' \
		-archivePath $(ARCHIVE_PATH)/Chips-iOS.xcarchive \
		| xcbeautify
	@echo "Creating macOS archive..."
	xcodebuild archive \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-destination 'generic/platform=macOS' \
		-archivePath $(ARCHIVE_PATH)/Chips-macOS.xcarchive \
		| xcbeautify
	@echo "Archives created in $(ARCHIVE_PATH)/"

# Requires App Store Connect API key configured
testflight: archive
	@echo "Uploading to TestFlight..."
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
	@echo "Ready for release!"
	@echo "1. Run 'make testflight' to upload"
	@echo "2. Submit for review in App Store Connect"

# =============================================================================
# CLOUDKIT
# =============================================================================

# Requires CloudKit schema export from Xcode
cloudkit-dev:
	@echo "Deploying CloudKit schema to Development..."
	@echo "Use Xcode: Product → Perform Action → Deploy Schema to Development"

cloudkit-prod:
	@echo "⚠️  WARNING: Deploying to Production is irreversible!"
	@read -p "Are you sure? (y/N) " confirm && [ "$$confirm" = "y" ] || exit 1
	@echo "Use Xcode: Product → Perform Action → Deploy Schema to Production"

# =============================================================================
# UTILITIES
# =============================================================================

docs:
	@echo "Generating documentation..."
	xcodebuild docbuild \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-destination 'platform=macOS' \
		-derivedDataPath build/docs
	@echo "Documentation generated in build/docs/"

screenshots:
	@echo "Generating App Store screenshots..."
	xcodebuild test \
		-project $(PROJECT) \
		-scheme ChipsUITests \
		-destination 'platform=iOS Simulator,name=iPhone 15 Pro Max' \
		-only-testing:ChipsUITests/ScreenshotTests \
		| xcbeautify
	@echo "Screenshots saved to Screenshots/"

loc:
	@echo "Lines of code:"
	@find . -name "*.swift" -not -path "./build/*" | xargs wc -l | tail -1

# Show all simulators
simulators:
	xcrun simctl list devices available

# Open project in Xcode
xcode:
	open $(PROJECT)

# Dump CloudKit schema (for version control)
cloudkit-export:
	@echo "Export schema from CloudKit Dashboard: "
	@echo "https://icloud.developer.apple.com/dashboard/"
```

### Makefile Usage Guidelines

1. **Always update the Makefile** when adding new scripts or commands
2. **Use targets for repeated commands** - if you run it twice, make it a target
3. **Keep help text current** - the `make help` output is developer documentation
4. **Version control** - commit Makefile changes with related code changes
5. **Platform-specific targets** - use suffixes like `-ios`, `-mac` for clarity

---

## 10. Dependencies

### Required
- **swift-markdown** (Apple) - Markdown parsing
- **Yams** (jpsim) - YAML frontmatter parsing

### Optional/Consider
- **SwiftUIX** - Additional SwiftUI components
- **KeychainAccess** - If storing any credentials

### Avoid
- Heavy third-party UI frameworks (use native SwiftUI)
- Firebase/other sync solutions (use CloudKit)

---

## 11. Success Criteria

### MVP Complete When:
- [ ] Can select iCloud Drive folder with markdown files
- [ ] Markdown files parse into chips correctly
- [ ] Tapping chip opens URL and logs interaction
- [ ] Timer action works with background tracking
- [ ] Can mark chips as complete (strikethrough)
- [ ] History tab shows all interactions
- [ ] Data syncs across iPhone, iPad, and Mac
- [ ] App available on TestFlight for all platforms

### Quality Bar:
- App launches in < 2 seconds
- Chip tap response < 100ms
- Sync completes within 30 seconds
- No data loss across 1000+ interactions
- Works offline, syncs when online

---

## 12. Share Extension

### 12.1 Overview
Allow users to share URLs, text, and other content from any app directly into Chips. The shared content will be added to a designated "Inbox" markdown file that can be organized later.

### 12.2 Supported Content Types
- **URLs**: Links from Safari, YouTube, etc.
- **Text**: Plain text selections
- **Images**: Save reference to image (optional)

### 12.3 User Flow
1. User taps Share in any app
2. Selects "Add to Chips"
3. Optionally adds tags or selects target list
4. Item is appended to inbox.md in iCloud Drive
5. Main app syncs and displays new chip

### 12.4 Implementation
- Share Extension target in Xcode project
- App Groups for shared data access
- Background sync to update main app

---

## 13. Open Questions / Future Considerations

1. **Widgets**: Show recent chips or today's activity on home screen?
2. **Shortcuts**: Siri Shortcuts integration for quick chip access?
3. **Watch App**: Companion app for Apple Watch?
4. **Sharing**: Share chip collections with others?
5. **Templates**: Pre-made markdown templates for common use cases?

---

## Next Steps

1. ✅ Approve this spec
2. Create Xcode project with multiplatform target
3. Set up CloudKit container in Apple Developer portal
4. Implement Phase 1: Foundation
