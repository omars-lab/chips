# Chips

A markdown-powered activity tracker for iOS, iPadOS, and macOS. Turn your markdown lists into interactive chips that track your progress on recurring activities like workout videos.

**GitHub**: [https://github.com/omars-lab/chips](https://github.com/omars-lab/chips)

## Features

- **Markdown-Powered**: Point the app to a folder in iCloud Drive containing your markdown files
- **Interactive Chips**: Each list item becomes a tappable chip with customizable actions
- **Activity Tracking**: Automatically logs every interaction with timestamps
- **Cross-Device Sync**: Full CloudKit sync across iPhone, iPad, and Mac
- **Smart Actions**: Open URLs in preferred apps (YouTube, Safari, etc.), track time with timers
- **History & Stats**: View your activity history, streaks, and usage statistics
- **Extended Syntax**: Support for tags (`#beginner`), inline actions (`@timer`, `@app:youtube`), and YAML frontmatter

## Example Markdown

```markdown
---
title: Treadmill Workouts
category: fitness
---

# Cardio Videos

- [30 Min HIIT Workout](https://youtube.com/watch?v=xxx) @timer @app:youtube #cardio
- [Walking Workout](https://youtube.com/watch?v=yyy) #beginner
- [ ] New video to try

## Strength Training

- [Upper Body](https://youtube.com/watch?v=zzz) @duration:45m
- [Core Workout](https://youtube.com/watch?v=aaa)
```

## Requirements

- **macOS**: 14.0+ (Sonoma)
- **iOS/iPadOS**: 17.0+
- **Xcode**: 15.0+
- **Swift**: 5.9+
- Apple Developer Account (for CloudKit)

## Quick Start

### 1. Install Dependencies

```bash
# Install required tools
brew install xcodegen swiftlint swiftformat xcbeautify

# Or use the setup command
make setup
```

### 2. Generate Xcode Project

```bash
make generate
```

### 3. Open in Xcode

```bash
make open
```

### 4. Configure Signing

1. Open Xcode project settings
2. Select the "Chips" target
3. Set your Development Team
4. Enable CloudKit capability and select/create a container

### 5. Build and Run

```bash
# Run on iPhone Simulator
make run-ios

# Run on iPad Simulator
make run-ipad

# Run on macOS
make run-mac
```

## Development Commands

Run `make help` to see all available commands:

```
Setup & Build:
  setup          - Install dependencies and generate Xcode project
  generate       - Regenerate Xcode project from project.yml
  build          - Build for all platforms (debug)
  build-ios      - Build for iOS only
  build-mac      - Build for macOS only
  clean          - Clean build artifacts

Running (Simulator):
  run-ios        - Build and run on iPhone 15 Simulator
  run-ipad       - Build and run on iPad Simulator
  run-mac        - Build and run macOS app
  open           - Open project in Xcode

Testing:
  test           - Run all unit tests
  test-ui        - Run UI tests
  test-coverage  - Run tests with coverage report

Code Quality:
  lint           - Run SwiftLint
  format         - Format code with SwiftFormat

Deployment:
  archive        - Create release archives
  testflight     - Upload to TestFlight
  release        - Full release process
```

## Project Structure

```
Chips/
├── App/                          # App entry point and main navigation
├── Models/                       # Core Data entities
├── Services/
│   ├── MarkdownParser/          # Markdown parsing engine
│   ├── CloudKit/                # Persistence and sync
│   ├── Actions/                 # Action handlers (URL, timer, etc.)
│   └── SourceManager/           # iCloud Drive file monitoring
├── ViewModels/                  # MVVM view models
├── Views/
│   ├── Chips/                   # Chips tab views
│   ├── History/                 # History tab views
│   ├── Settings/                # Settings tab views
│   └── Shared/                  # Reusable components
└── Resources/                   # Assets, Info.plist, entitlements
```

## Architecture

- **SwiftUI**: Native UI framework for all platforms
- **MVVM**: Clean separation of views and business logic
- **Core Data + CloudKit**: Local persistence with automatic cloud sync
- **XcodeGen**: Project generation from YAML specification

## Testing

```bash
# Run unit tests
make test

# Run UI tests
make test-ui

# Run with coverage
make test-coverage
```

## Deployment

### TestFlight (Internal Testing)

1. Configure your App Store Connect API key
2. Run `make testflight`
3. Add internal testers in App Store Connect

### App Store Release

1. Run `make release`
2. Submit for review in App Store Connect

## CloudKit Setup

1. Go to [CloudKit Dashboard](https://icloud.developer.apple.com/dashboard/)
2. Create a container: `iCloud.com.chips.app`
3. Deploy schema to Development (from Xcode)
4. Before release: Deploy schema to Production

## Contributing

1. Fork the [repository](https://github.com/omars-lab/chips)
2. Create a feature branch
3. Run `make lint` and `make format` before committing
4. Submit a pull request

## License

MIT License - see LICENSE file for details.
