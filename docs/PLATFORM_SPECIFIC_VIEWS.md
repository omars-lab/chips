# Platform-Specific Views with Shared Components

This document explains how to structure platform-specific views (iPad, Mac, iPhone) while maximizing code reuse through shared components.

> **See [PLATFORM_VIEWS_ANALYSIS.md](./PLATFORM_VIEWS_ANALYSIS.md) for a detailed pros/cons analysis and recommendations for this codebase.**

## Architecture Pattern

### Structure

```
Chips/Views/
├── Chips/
│   ├── ChipsTabView.swift          # Main container (platform-agnostic)
│   ├── ChipListView.swift          # Shared list/grid container
│   ├── ChipRowView.swift           # Shared component (works on all platforms)
│   ├── ChipCardView.swift          # Shared component (works on all platforms)
│   ├── Platform/
│   │   ├── ChipsTabView_iOS.swift  # iPhone-specific implementation
│   │   ├── ChipsTabView_iPad.swift # iPad-specific implementation
│   │   └── ChipsTabView_macOS.swift # Mac-specific implementation
│   └── Shared/
│       └── ChipContent.swift       # Shared chip content (if needed)
├── Shared/                         # Cross-platform reusable components
│   ├── ChipLogoView.swift
│   ├── FloatingTimerView.swift
│   └── FolderPickerView.swift
└── Platform/                       # Platform-specific shared components
    ├── iOS/
    ├── iPad/
    └── macOS/
```

## Pattern 1: Platform-Specific Views with Shared Components

### Example: ChipsTabView

**Shared Component (ChipsTabView.swift):**
```swift
import SwiftUI
import CoreData

struct ChipsTabView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var viewModel = ChipsViewModel()
    
    var body: some View {
        #if os(iOS)
        if UIDevice.current.userInterfaceIdiom == .pad {
            ChipsTabView_iPad(viewModel: viewModel)
        } else {
            ChipsTabView_iOS(viewModel: viewModel)
        }
        #elseif os(macOS)
        ChipsTabView_macOS(viewModel: viewModel)
        #endif
    }
}
```

**iPhone-Specific (ChipsTabView_iOS.swift):**
```swift
import SwiftUI

struct ChipsTabView_iOS: View {
    @ObservedObject var viewModel: ChipsViewModel
    @Environment(\.managedObjectContext) private var viewContext
    
    var body: some View {
        NavigationStack {
            // iPhone-optimized layout
            ChipListView(
                source: viewModel.selectedSource,
                searchText: viewModel.searchText,
                useGridLayout: false  // Always list on iPhone
            )
            .navigationTitle("Chips")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        viewModel.showSourcePicker = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
    }
}
```

**iPad-Specific (ChipsTabView_iPad.swift):**
```swift
import SwiftUI

struct ChipsTabView_iPad: View {
    @ObservedObject var viewModel: ChipsViewModel
    @Environment(\.managedObjectContext) private var viewContext
    
    var body: some View {
        NavigationStack {
            // iPad-optimized layout with split view support
            ChipListView(
                source: viewModel.selectedSource,
                searchText: viewModel.searchText,
                useGridLayout: true  // Grid layout on iPad
            )
            .navigationTitle("Chips")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        viewModel.showSourcePicker = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
    }
}
```

**Mac-Specific (ChipsTabView_macOS.swift):**
```swift
import SwiftUI

struct ChipsTabView_macOS: View {
    @ObservedObject var viewModel: ChipsViewModel
    @Environment(\.managedObjectContext) private var viewContext
    
    var body: some View {
        NavigationStack {
            // Mac-optimized layout
            ChipListView(
                source: viewModel.selectedSource,
                searchText: viewModel.searchText,
                useGridLayout: true  // Grid layout on Mac
            )
            .navigationTitle("Chips")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        viewModel.showSourcePicker = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .keyboardShortcut("n", modifiers: .command)
                }
            }
        }
        .frame(minWidth: 600, minHeight: 400)
    }
}
```

## Pattern 2: Shared Components with Platform Adaptations

### Example: ChipRowView (Already Implemented)

The `ChipRowView` is a shared component that adapts to platforms using `#if os()` checks:

```swift
struct ChipRowView: View {
    // ... shared properties ...
    
    var body: some View {
        #if os(macOS)
        // Mac-specific button behavior
        Button(action: { executeAction() }) {
            chipContent
        }
        .buttonStyle(.plain)
        .contextMenu { /* Mac context menu */ }
        #else
        // iOS-specific behavior
        chipContent
        .swipeActions { /* iOS swipe actions */ }
        #endif
    }
    
    // Shared content (used by all platforms)
    private var chipContent: some View {
        HStack {
            // Shared UI components
            ChipViewHelpers.actionIcon(for: chip)
            Text(viewModel.displayTitle)
            // ...
        }
    }
}
```

## Pattern 3: View Modifiers for Platform-Specific Styling

### Example: Platform-Specific Modifiers

```swift
extension View {
    /// Applies platform-specific styling
    func platformAdaptive() -> some View {
        #if os(macOS)
        self
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        #elseif os(iOS)
        self
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        #endif
    }
    
    /// Platform-specific navigation bar styling
    func platformNavigationBar() -> some View {
        #if os(iOS)
        self.navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }
}
```

## Pattern 4: Shared ViewModel with Platform-Specific Logic

### Example: ChipsViewModel

```swift
@MainActor
final class ChipsViewModel: ObservableObject {
    @Published var selectedSource: ChipSource?
    @Published var searchText = ""
    @Published var showSourcePicker = false
    
    // Platform-specific computed properties
    var useGridLayout: Bool {
        #if os(macOS)
        return true
        #elseif os(iOS)
        return UIDevice.current.userInterfaceIdiom == .pad
        #else
        return false
        #endif
    }
    
    var toolbarPlacement: ToolbarItemPlacement {
        #if os(macOS)
        return .primaryAction
        #else
        return .navigationBarTrailing
        #endif
    }
}
```

## Best Practices

### 1. **Maximize Shared Components**

- ✅ **DO**: Share components like `ChipRowView`, `ChipCardView`, `ChipViewHelpers`
- ✅ **DO**: Use shared ViewModels (`ChipViewModel`, `ChipsViewModel`)
- ✅ **DO**: Extract common UI patterns into reusable components

### 2. **Platform-Specific Views Only When Necessary**

- ✅ **DO**: Create platform-specific views when:
  - Layout significantly differs (e.g., iPhone vs iPad)
  - Navigation patterns differ (e.g., TabView vs NavigationSplitView)
  - Interaction patterns differ (e.g., context menu vs swipe actions)
  
- ❌ **DON'T**: Create platform-specific views for minor styling differences (use modifiers instead)

### 3. **Use `#if os()` Sparingly**

- ✅ **DO**: Use `#if os()` for:
  - Import statements
  - Platform-specific APIs
  - Minor UI adaptations
  
- ❌ **DON'T**: Use `#if os()` for entire view structures (create separate files instead)

### 4. **Shared Components Location**

- **`Views/Shared/`**: Components used across multiple tabs/features
- **`Views/Chips/Shared/`**: Components specific to chips feature
- **`Views/Platform/`**: Platform-specific implementations

## Example: Complete Platform-Specific Implementation

### Step 1: Create Shared ViewModel

```swift
// Chips/ViewModels/ChipsViewModel.swift
@MainActor
final class ChipsViewModel: ObservableObject {
    @Published var selectedSource: ChipSource?
    @Published var searchText = ""
    @Published var showSourcePicker = false
    
    // Shared logic for all platforms
    func selectSource(_ source: ChipSource) {
        selectedSource = source
    }
}
```

### Step 2: Create Platform-Specific Views

```swift
// Chips/Views/Chips/Platform/ChipsTabView_iOS.swift
struct ChipsTabView_iOS: View {
    @ObservedObject var viewModel: ChipsViewModel
    @Environment(\.managedObjectContext) private var viewContext
    
    var body: some View {
        NavigationStack {
            ChipListView(
                source: viewModel.selectedSource,
                searchText: viewModel.searchText,
                useGridLayout: false
            )
            .navigationTitle("Chips")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        viewModel.showSourcePicker = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
    }
}
```

### Step 3: Use Shared Components

```swift
// Chips/Views/Chips/ChipListView.swift (Shared)
struct ChipListView: View {
    let source: ChipSource?
    let searchText: String
    let useGridLayout: Bool
    
    var body: some View {
        if useGridLayout {
            ChipGridView(chips: filteredChips)
        } else {
            List(filteredChips) { chip in
                ChipRowView(chip: chip)  // Shared component
            }
        }
    }
}
```

## Migration Strategy

### Current State
- Uses `#if os()` checks within views
- Uses `horizontalSizeClass` for iPad/iPhone differentiation
- Shared components already exist (`ChipRowView`, `ChipCardView`)

### Recommended Migration

1. **Keep shared components** (`ChipRowView`, `ChipCardView`, `ChipViewHelpers`)
2. **Extract platform-specific logic** into separate view files when:
   - Layout significantly differs
   - Navigation patterns differ
   - Interaction patterns differ
3. **Use ViewModels** to share business logic across platforms
4. **Use modifiers** for minor styling differences

## Example: Migrating ChipsTabView

### Before (Current):
```swift
struct ChipsTabView: View {
    private var useGridLayout: Bool {
        #if os(macOS)
        return true
        #else
        return horizontalSizeClass == .regular
        #endif
    }
    
    var body: some View {
        // Mixed platform logic
    }
}
```

### After (Platform-Specific):
```swift
// ChipsTabView.swift (Router)
struct ChipsTabView: View {
    @StateObject private var viewModel = ChipsViewModel()
    
    var body: some View {
        #if os(iOS)
        if UIDevice.current.userInterfaceIdiom == .pad {
            ChipsTabView_iPad(viewModel: viewModel)
        } else {
            ChipsTabView_iOS(viewModel: viewModel)
        }
        #elseif os(macOS)
        ChipsTabView_macOS(viewModel: viewModel)
        #endif
    }
}

// ChipsTabView_iOS.swift
struct ChipsTabView_iOS: View {
    @ObservedObject var viewModel: ChipsViewModel
    
    var body: some View {
        ChipListView(useGridLayout: false)  // Shared component
    }
}

// ChipsTabView_iPad.swift
struct ChipsTabView_iPad: View {
    @ObservedObject var viewModel: ChipsViewModel
    
    var body: some View {
        ChipListView(useGridLayout: true)  // Shared component
    }
}
```

## Benefits

1. **Clear Separation**: Platform-specific code is isolated
2. **Easy Testing**: Test platform-specific views independently
3. **Code Reuse**: Shared components reduce duplication
4. **Maintainability**: Changes to one platform don't affect others
5. **Readability**: Each file focuses on one platform's needs

## Summary

- ✅ **Create platform-specific views** when layouts/interactions differ significantly
- ✅ **Reuse shared components** (`ChipRowView`, `ChipCardView`, `ChipViewHelpers`)
- ✅ **Use shared ViewModels** for business logic
- ✅ **Use modifiers** for minor styling differences
- ✅ **Keep `#if os()` checks** minimal and focused on API differences

