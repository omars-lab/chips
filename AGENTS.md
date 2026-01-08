# AGENTS.md - Agent Development Guide

This document provides comprehensive information for AI agents and developers to understand, extend, and contribute to the Chips codebase.

## Table of Contents

1. [Quick Start](#quick-start)
2. [Project Architecture](#project-architecture)
3. [Core Concepts](#core-concepts)
4. [Key Components](#key-components)
5. [Extension Points](#extension-points)
6. [Code Simplification Opportunities](#code-simplification-opportunities)
7. [Development Workflow](#development-workflow)
8. [Testing Strategy](#testing-strategy)

---

## Quick Start

### Prerequisites

```bash
# Required tools
brew install xcodegen swiftlint swiftformat xcbeautify

# Or use the setup command
make setup
```

### Initial Setup

```bash
# 1. Generate Xcode project from project.yml
make generate

# 2. Open in Xcode
make open

# 3. Configure signing in Xcode:
#    - Select "Chips" target
#    - Set Development Team
#    - Enable CloudKit capability
#    - Select/create container: iCloud.com.chips.app

# 4. Build and run
make run-mac    # macOS
make run-ios    # iOS Simulator
make run-ipad   # iPad Simulator
```

### Project Generation

The project uses **XcodeGen** to generate Xcode projects from `project.yml`. This ensures:
- Consistent project structure
- No merge conflicts in `.pbxproj` files
- Easy platform-specific configuration

**Important**: Always run `make generate` after modifying `project.yml` or adding new files.

---

## Project Architecture

### High-Level Structure

```
Chips/
├── App/                    # Entry point and root navigation
│   ├── ChipsApp.swift     # @main app struct
│   └── ContentView.swift  # Root tab/sidebar view
│
├── Models/                # Core Data entities (auto-generated + extensions)
│   ├── Chip.swift         # Main chip entity
│   ├── ChipSource.swift   # Markdown source files
│   ├── ChipInteraction.swift  # Activity logs
│   └── ChipActionConfiguration.swift  # Custom action configs
│
├── Services/              # Business logic layer
│   ├── Actions/           # Action execution engine
│   ├── CloudKit/         # Persistence & sync
│   ├── MarkdownParser/   # Markdown parsing
│   ├── SourceManager/    # File monitoring
│   └── Summarization/    # URL metadata & summarization
│
├── ViewModels/           # MVVM view models
│   ├── ChipsViewModel.swift
│   ├── HistoryViewModel.swift
│   └── ChipViewModel.swift  # Shared ViewModel for chip views
│
├── Views/                 # SwiftUI views
│   ├── Chips/            # Chips tab
│   ├── History/          # History tab
│   ├── Settings/         # Settings tab
│   └── Shared/           # Reusable components
│
└── Resources/            # Assets, Info.plist, entitlements
```

### Architecture Patterns

- **MVVM**: Views observe ViewModels, ViewModels coordinate Services
- **Singleton Services**: `ActionEngine.shared`, `TimerManager.shared`, etc.
- **Core Data + CloudKit**: Local persistence with automatic cloud sync
- **SwiftUI**: Declarative UI framework (iOS 17+, macOS 14+)

---

## Core Concepts

### 1. Chip Entity

A **Chip** represents an interactive list item from markdown files.

**Key Properties:**
- `title`: Display text (from markdown list item)
- `actionType`: `"url"`, `"timer"`, `"app"`, or `"custom"`
- `actionPayload`: JSON string with action-specific data
- `metadata`: JSON string with tags, summary, etc.
- `isCompleted`: Boolean for completion status
- `interactions`: Relationship to `ChipInteraction` entities

**Example:**
```swift
let chip = Chip(context: context)
chip.title = "30 Min HIIT Workout"
chip.actionType = "url"
chip.actionPayload = """
{
  "url": "https://youtube.com/watch?v=xxx",
  "preferredApp": "youtube",
  "expectedDuration": 1800
}
"""
chip.metadata = """
{
  "tags": ["cardio", "hiit"],
  "summary": "High-intensity interval training workout"
}
"""
```

### 2. Action Execution Flow

```
User clicks chip
    ↓
ChipRowView/ChipGridView → ActionEngine.execute()
    ↓
ActionEngine checks for custom configuration
    ↓
If found: executeConfiguredAction()
If not: execute default action (URL, timer, app)
    ↓
Action executes (opens URL, starts timer, etc.)
    ↓
Metadata fetched asynchronously (if URL present)
    ↓
Interaction logged to Core Data
```

### 3. Markdown Parsing

Markdown files are parsed to extract:
- **List items** → Chips
- **Tags** (`#cardio`) → Stored in `chip.metadata`
- **Inline actions** (`@timer`, `@app:youtube`) → Stored in `chip.actionPayload`
- **YAML frontmatter** → Stored in `ChipSource` metadata

**Example Markdown:**
```markdown
---
title: Workout Videos
category: fitness
---

# Cardio

- [30 Min HIIT](https://youtube.com/watch?v=xxx) @timer @app:youtube #cardio
- [Walking Workout](https://youtube.com/watch?v=yyy) #beginner
```

### 4. CloudKit Sync

- Uses `NSPersistentCloudKitContainer`
- Automatic sync across devices
- Schema defined in `CoreDataModel.xcdatamodeld`
- Container: `iCloud.com.chips.app`

**Important**: Schema changes must be deployed to CloudKit Dashboard before release.

---

## Key Components

### ActionEngine (`Chips/Services/Actions/ActionEngine.swift`)

Central engine for executing chip actions.

**Key Methods:**
- `execute(chip:context:)` - Main entry point
- `executeConfiguredAction(config:chip:context:)` - Custom actions
- `executeURLAction(actionData:chip:)` - URL actions
- `fetchMetadataIfNeeded(for:)` - Async metadata fetching

**Usage:**
```swift
ActionEngine.shared.execute(chip: chip, context: viewContext)
```

### ChipActionConfigurationManager (`Chips/Services/Actions/ChipActionConfigurationManager.swift`)

Manages custom action configurations that match chips by URL pattern or tags.

**Key Methods:**
- `findConfiguration(for:context:)` - Find matching config
- `buildActionURLs(from:chip:)` - Build action URLs with variables
- `matchesPattern(pattern:url:)` - Pattern matching logic

**Example Configuration:**
- Pattern: `youtube.com`
- Tags: `none`
- Actions: Open NotePlan, then open YouTube URL

### URLMetadataFetcher (`Chips/Services/Summarization/URLMetadataFetcher.swift`)

Fetches metadata from URLs (Open Graph, HTML meta tags, oEmbed).

**Key Methods:**
- `fetchMetadata(from:)` - Main fetch method
- `fetchYouTubeMetadata(from:)` - YouTube oEmbed API

**Returns:**
```swift
struct URLMetadata {
    let title: String?
    let description: String?
    let imageURL: String?
    let siteName: String?
    let type: String?
    let rawHTML: String?
}
```

### PersistenceController (`Chips/Services/CloudKit/PersistenceController.swift`)

Manages Core Data stack with CloudKit sync.

**Key Properties:**
- `shared` - Singleton instance
- `container` - `NSPersistentCloudKitContainer`
- `viewContext` - Main context for UI

**Usage:**
```swift
let context = PersistenceController.shared.container.viewContext
```

---

## Extension Points

### 1. Adding a New Action Type

**Steps:**

1. **Update Core Data Model** (`CoreDataModel.xcdatamodeld`):
   - Add new action type to `Chip.actionType` enum (if needed)

2. **Extend ActionEngine** (`Chips/Services/Actions/ActionEngine.swift`):
   ```swift
   case "newAction":
       executeNewAction(actionData: actionData, chip: chip)
   ```

3. **Implement Action Handler**:
   ```swift
   private func executeNewAction(actionData: ActionPayload?, chip: Chip) {
       // Your action logic here
   }
   ```

4. **Update Markdown Parser** (if needed):
   - Add parsing for new inline action syntax

### 2. Adding a New Service

**Pattern:**
```swift
@MainActor
final class NewService {
    static let shared = NewService()
    private init() {}
    
    // Your service methods
}
```

**Place in:** `Chips/Services/NewService/`

### 3. Adding a New View

**Pattern:**
```swift
struct NewView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    var body: some View {
        // Your view
    }
}
```

**Place in:** `Chips/Views/` (appropriate subdirectory)

### 4. Adding Metadata Fetching for New Platform

**Extend URLMetadataFetcher** (`Chips/Services/Summarization/URLMetadataFetcher.swift`):

```swift
private func fetchNewPlatformMetadata(from url: URL) async -> URLMetadata? {
    // Check if URL matches platform
    guard url.host?.contains("newplatform.com") == true else {
        return nil
    }
    
    // Fetch metadata (oEmbed, API, etc.)
    // Return URLMetadata
}
```

Then add to `fetchMetadata(from:)`:
```swift
if let metadata = await fetchNewPlatformMetadata(from: url) {
    return metadata
}
```

### 5. Adding a New ViewModel

**Pattern:**
```swift
@MainActor
final class NewViewModel: ObservableObject {
    @Published var data: [SomeType] = []
    
    func loadData() {
        // Load logic
    }
}
```

---

## Code Simplification Opportunities

### 1. Consolidate URL Extraction Logic

**Current Issue:**
- URL extraction duplicated in multiple places:
  - `ChipRowView.extractURL(from:)`
  - `ActionEngine.extractURLFromTitle(_:)`
  - `ChipActionConfigurationManager.extractURL(from:)`
  - `ChipSummaryService.extractURL(from:)`

**Solution:**
Create a shared utility:
```swift
// Chips/Utilities/Extensions/String+URL.swift
extension String {
    func extractURL() -> String? {
        let trimmed = self.trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = URL(string: trimmed), url.scheme != nil {
            return trimmed
        }
        return nil
    }
}
```

### 2. Simplify Metadata Storage ✅ IMPLEMENTED

**Status:** `Chip.chipMetadata` computed property already exists with getter/setter

**Usage:**
```swift
// Get metadata
let tags = chip.chipMetadata?.tags

// Set metadata
var meta = chip.chipMetadata ?? ChipMetadata()
meta.tags = ["new", "tags"]
chip.chipMetadata = meta
```

**Note:** `ActionPayload` also has getter/setter via `chip.actionData`

### 3. Consolidate Logging ✅ IMPLEMENTED

**Status:** Created `AppLogger` utility in `Chips/Utilities/Logging.swift`

**Usage:**
```swift
// Instead of:
let logger = Logger(subsystem: "com.chips.app", category: "MyCategory")
logger.info("Message")
print("Message")

// Use:
AppLogger.info("Message", category: "MyCategory")
AppLogger.debug("Debug message")
AppLogger.warning("Warning message")
AppLogger.error("Error message")
```

**Migration:** Gradually replace Logger instances with AppLogger calls

### 4. Simplify Action Payload ✅ IMPLEMENTED

**Status:** `Chip.actionData` computed property already exists with getter/setter

**Usage:**
```swift
// Get action data
let url = chip.actionData?.url

// Set action data
var payload = chip.actionData ?? ActionPayload()
payload.url = "https://example.com"
chip.actionData = payload
```

### 5. Remove Duplicate View Helper Code ✅ IMPLEMENTED

**Status:** Created `ChipViewHelpers` utility for shared chip view logic

**Solution:**
```swift
// Chips/Utilities/ChipViewHelpers.swift
enum ChipViewHelpers {
    static func actionIcon(for chip: Chip) -> some View { ... }
    static func iconBackgroundColor(for chip: Chip) -> Color { ... }
    static func formatDuration(_ seconds: TimeInterval) -> String { ... }
    static func toggleCompleted(
        for chip: Chip,
        in context: NSManagedObjectContext,
        timerManager: TimerManager,
        isActiveTimer: Bool
    ) { ... }
}
```

**Usage:**
```swift
// Instead of duplicating actionIcon logic:
ChipViewHelpers.actionIcon(for: chip)

// Instead of duplicating toggleCompleted:
ChipViewHelpers.toggleCompleted(
    for: chip,
    in: viewContext,
    timerManager: timerManager,
    isActiveTimer: isActiveTimer
)
```

**Benefits:**
- Shared logic for action icons, completion toggling, duration formatting
- Consistent behavior across all chip views
- Easier to maintain and extend

### 6. Simplify State Management ✅ IMPLEMENTED

**Status:** Created `ChipViewModel` to centralize all chip-related state and logic

**Solution:**
```swift
@MainActor
final class ChipViewModel: ObservableObject {
    @Published var metadata: URLMetadataFetcher.URLMetadata?
    @Published var showingSummary = false
    @Published var isGeneratingSummary = false
    @Published var summary: String?
    @Published var showingMetadata = false
    @Published var isFetchingMetadata = false
    
    var displayTitle: String { ... }
    var thumbnailURL: String? { ... }
    
    func loadMetadataFromChip() { ... }
    func checkAndFetchMetadata() async { ... }
    func fetchAndShowMetadata() async { ... }
    func generateSummary(description: String?) async { ... }
    func onAppear() { ... }
    func onMetadataChanged(oldValue: String?, newValue: String?) { ... }
}
```

**Usage:**
```swift
@StateObject private var viewModel: ChipViewModel

init(chip: Chip) {
    let context = chip.managedObjectContext ?? PersistenceController.shared.container.viewContext
    _viewModel = StateObject(wrappedValue: ChipViewModel(chip: chip, context: context))
}

// Use viewModel.displayTitle, viewModel.thumbnailURL, etc.
.onAppear {
    viewModel.onAppear()
}
```

**Benefits:**
- Single source of truth for chip metadata/summary logic
- Consistent behavior across `ChipRowView` and `ChipCardView`
- Easier to test and maintain
- See `docs/SHARED_LOGIC.md` for full documentation

### 8. Consolidate Metadata Fetching

**Current Issue:**
- Metadata fetching logic in both `ChipRowView` and `ActionEngine`
- Duplicate `checkAndFetchMetadata()` and `fetchMetadataIfNeeded()` methods

**Status:** ✅ PARTIALLY IMPLEMENTED - Metadata fetching added to `ActionEngine`

**Recommendation:** 
- Remove metadata fetching from `ChipRowView` (now handled by `ActionEngine`)
- Keep `ChipRowView.fetchAndShowMetadata()` only for manual "View Metadata" action

### 7. Extract Constants

**Current Issue:**
- Magic strings scattered throughout code
- Hardcoded URLs, identifiers, etc.

**Solution:**
Create constants file:
```swift
// Chips/Utilities/Constants.swift
enum AppConstants {
    static let bundleID = "com.chips.app"
    static let cloudKitContainer = "iCloud.com.chips.app"
    static let loggerSubsystem = "com.chips.app"
}
```

---

## Development Workflow

### 1. Making Changes

```bash
# 1. Create feature branch
git checkout -b feature/new-feature

# 2. Make changes
# Edit files...

# 3. Regenerate project (if structure changed)
make generate

# 4. Build and test
make run-mac

# 5. Lint and format
make lint
make format

# 6. Commit
git add .
git commit -m "Add new feature"
```

### 2. Adding New Files

1. **Create file** in appropriate directory
2. **Run `make generate`** to add to Xcode project
3. **Build** to verify compilation

### 3. Testing Changes

```bash
# Run unit tests
make test

# Run UI tests
make test-ui

# Run with coverage
make test-coverage
```

### 4. Debugging

**View Logs:**
```bash
# macOS logs
log stream --predicate 'subsystem == "com.chips.app"' --level debug

# Or use the script
./scripts/view-logs.sh
```

**Common Issues:**
- **CloudKit errors**: Check container configuration in Xcode
- **Build errors**: Run `make clean && make generate`
- **Missing files**: Run `make generate` after adding files

---

## Testing Strategy

### Unit Tests

**Location:** `ChipsTests/`

**Key Test Files:**
- `MarkdownParserTests.swift` - Markdown parsing
- `TagExtractorTests.swift` - Tag extraction

**Running Tests:**
```bash
make test
```

### UI Tests

**Location:** `ChipsUITests/`

**Running UI Tests:**
```bash
make test-ui
```

### Test Coverage

```bash
make test-coverage
# Open coverage report in Xcode
```

---

## Common Tasks for Agents

### Adding a New Feature

1. **Understand the domain**: Read relevant service files
2. **Identify extension points**: Use patterns above
3. **Implement incrementally**: Small, testable changes
4. **Update documentation**: Add to relevant docs
5. **Test thoroughly**: Unit tests + manual testing

### Fixing Bugs

1. **Reproduce**: Understand the issue
2. **Locate code**: Use codebase search
3. **Fix**: Make minimal changes
4. **Test**: Verify fix works
5. **Document**: Add to docs if needed

### Refactoring

1. **Identify duplication**: Look for repeated patterns
2. **Extract common code**: Create utilities/extensions
3. **Update all call sites**: Use find/replace carefully
4. **Test**: Ensure behavior unchanged
5. **Simplify**: Remove unnecessary complexity

---

## Key Files Reference

### Entry Points
- `Chips/App/ChipsApp.swift` - App entry point
- `Chips/App/ContentView.swift` - Root view

### Core Services
- `Chips/Services/Actions/ActionEngine.swift` - Action execution
- `Chips/Services/CloudKit/PersistenceController.swift` - Data persistence
- `Chips/Services/MarkdownParser/MarkdownParser.swift` - Markdown parsing

### Main Views
- `Chips/Views/Chips/ChipsTabView.swift` - Chips tab
- `Chips/Views/Chips/ChipRowView.swift` - Individual chip view
- `Chips/Views/Settings/SettingsTabView.swift` - Settings

### Configuration
- `project.yml` - XcodeGen project specification
- `Makefile` - Build commands
- `Chips/Resources/Info.plist` - App metadata
- `Chips/Resources/Chips.entitlements` - Capabilities

---

## Resources

- **GitHub**: https://github.com/omars-lab/chips
- **Documentation**: See `docs/` directory
- **Specification**: See `SPEC.md`
- **XcodeGen Docs**: https://github.com/yonaskolb/XcodeGen

---

## Notes for Agents

1. **Always run `make generate`** after modifying project structure
2. **Use `@MainActor`** for UI-related code
3. **Follow MVVM pattern**: Views → ViewModels → Services
4. **Test on multiple platforms**: iOS, iPadOS, macOS
5. **Check CloudKit implications** when modifying Core Data models
6. **Use `AppLogger`** for consistent logging (combines Logger + print)
7. **Keep views simple**: Extract complex logic to ViewModels/Services
8. **Use utility extensions**: `String.extractURL()`, `AppConstants`, etc.
9. **Avoid code duplication**: Use shared ViewModels and utilities
10. **Use `ChipViewModel`** for chip-related state and metadata logic
11. **Use `ChipViewHelpers`** for shared view helper functions
12. **When adding features to chip views**: Add to `ChipViewModel` or `ChipViewHelpers` first

---

## Quick Reference: Common Patterns

### Creating a New Service

```swift
@MainActor
final class MyService {
    static let shared = MyService()
    private init() {}
    
    func doSomething() async {
        AppLogger.info("Doing something...", category: "MyService")
        // Implementation
    }
}
```

### Extracting URL from Chip

```swift
// Use extension:
let url = chip.unwrappedTitle.extractURL()
// Or:
let url = chip.actionData?.url ?? chip.unwrappedTitle.extractURL()
```

### Accessing Chip Data

```swift
// Action data (type-safe)
let url = chip.actionData?.url
chip.actionData = ActionPayload(url: "https://example.com")

// Metadata (type-safe)
let tags = chip.chipMetadata?.tags
var meta = chip.chipMetadata ?? ChipMetadata()
meta.tags = ["new", "tags"]
chip.chipMetadata = meta
```

### Logging

```swift
// Use AppLogger for consistent logging:
AppLogger.info("Message", category: "MyCategory")
AppLogger.debug("Debug message")
AppLogger.warning("Warning")
AppLogger.error("Error")
```

### Using ChipViewModel (Shared State Management)

```swift
// In ChipRowView or ChipCardView:
@StateObject private var viewModel: ChipViewModel

init(chip: Chip) {
    let context = chip.managedObjectContext ?? PersistenceController.shared.container.viewContext
    _viewModel = StateObject(wrappedValue: ChipViewModel(chip: chip, context: context))
}

// Use viewModel properties:
Text(viewModel.displayTitle)
if let url = viewModel.thumbnailURL { ... }
.sheet(isPresented: $viewModel.showingMetadata) { ... }

// Call viewModel methods:
.onAppear {
    viewModel.onAppear()
}
.onChange(of: chip.metadata) { oldValue, newValue in
    viewModel.onMetadataChanged(oldValue: oldValue, newValue: newValue)
}
```

### Using ChipViewHelpers (Shared View Logic)

```swift
// Action icon:
ChipViewHelpers.actionIcon(for: chip)

// Icon background color:
ChipViewHelpers.iconBackgroundColor(for: chip)

// Format duration:
ChipViewHelpers.formatDuration(TimeInterval(1800)) // "30m"

// Toggle completion:
ChipViewHelpers.toggleCompleted(
    for: chip,
    in: viewContext,
    timerManager: timerManager,
    isActiveTimer: isActiveTimer
)
```

---

## Key Learnings: Shared Logic Patterns

### When to Create a Shared ViewModel

Create a ViewModel when:
- **Multiple views share the same state** (e.g., `ChipRowView` and `ChipCardView`)
- **Complex state synchronization** is needed
- **Business logic** should be separated from view code
- **Testing** the logic independently is important

**Example:** `ChipViewModel` centralizes metadata fetching, summary generation, and thumbnail logic used by both chip views.

### When to Create Shared Utilities

Create utility functions/enums when:
- **Simple helper functions** are duplicated across views
- **Pure functions** that don't need state management
- **Computed properties** that don't depend on view state
- **Formatting/conversion** logic

**Example:** `ChipViewHelpers` provides action icons, duration formatting, and completion toggling.

### Migration Pattern

When refactoring duplicate code:

1. **Identify duplication**: Look for identical or very similar code blocks
2. **Extract to ViewModel**: If it involves state management
3. **Extract to Utilities**: If it's pure functions/computed properties
4. **Update all call sites**: Replace old code with new shared code
5. **Test thoroughly**: Ensure behavior is identical
6. **Document**: Add to AGENTS.md and create docs if needed

### Benefits of Shared Logic

- **Single Source of Truth**: Fix bugs once, affects all views
- **Consistency**: All views behave identically
- **Maintainability**: Easier to understand and modify
- **Testability**: Can test logic independently
- **Reusability**: Can be used by future views

---

Last Updated: 2025-01-XX

