# Shared Logic Pattern - ChipViewModel

## Problem

Previously, `ChipRowView` and `ChipCardView` had duplicate logic for:
- Metadata fetching and storage
- Summary generation
- Thumbnail URL computation
- Display title computation
- Context menu actions

This violated DRY (Don't Repeat Yourself) principles and made maintenance difficult.

## Solution

Created `ChipViewModel` to centralize all shared logic:

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
    var hasURL: Bool { ... }
    
    func loadMetadataFromChip() { ... }
    func checkAndFetchMetadata() async { ... }
    func fetchAndShowMetadata() async { ... }
    func generateSummary(description: String?) async { ... }
    func onAppear() { ... }
    func onMetadataChanged(oldValue: String?, newValue: String?) { ... }
}
```

## Usage Pattern

### In ChipRowView or ChipCardView:

```swift
@StateObject private var viewModel: ChipViewModel

init(chip: Chip) {
    let context = chip.managedObjectContext ?? PersistenceController.shared.container.viewContext
    _viewModel = StateObject(wrappedValue: ChipViewModel(chip: chip, context: context))
}

var body: some View {
    // Use viewModel.displayTitle instead of displayTitle
    Text(viewModel.displayTitle)
    
    // Use viewModel.thumbnailURL instead of thumbnailURL
    if let url = viewModel.thumbnailURL { ... }
    
    // Use viewModel.metadata instead of @State metadata
    if let metadata = viewModel.metadata { ... }
    
    // Use viewModel properties for bindings
    .sheet(isPresented: $viewModel.showingMetadata) { ... }
    
    // Call viewModel methods
    .onAppear {
        viewModel.onAppear()
    }
    .onChange(of: chip.metadata) { oldValue, newValue in
        viewModel.onMetadataChanged(oldValue: oldValue, newValue: newValue)
    }
}
```

## Benefits

1. **Single Source of Truth**: All metadata/summary logic in one place
2. **Consistency**: Both views behave identically
3. **Maintainability**: Fix bugs or add features in one place
4. **Testability**: ViewModel can be tested independently
5. **Reusability**: Can be used by any chip view

## Migration Checklist

When refactoring a view to use ChipViewModel:

- [ ] Replace `@State private var metadata` with `@StateObject private var viewModel`
- [ ] Replace `metadata` references with `viewModel.metadata`
- [ ] Replace `summary` references with `viewModel.summary`
- [ ] Replace `showingSummary` with `viewModel.showingSummary`
- [ ] Replace `isGeneratingSummary` with `viewModel.isGeneratingSummary`
- [ ] Replace `showingMetadata` with `viewModel.showingMetadata`
- [ ] Replace `isFetchingMetadata` with `viewModel.isFetchingMetadata`
- [ ] Replace `displayTitle` computed property with `viewModel.displayTitle`
- [ ] Replace `thumbnailURL` computed property with `viewModel.thumbnailURL`
- [ ] Replace method calls:
  - `checkAndFetchMetadata()` → `viewModel.checkAndFetchMetadata()`
  - `fetchAndShowMetadata()` → `viewModel.fetchAndShowMetadata()`
  - `generateSummary()` → `viewModel.generateSummary()`
  - `loadMetadataFromChip()` → `viewModel.loadMetadataFromChip()`
- [ ] Update `.onAppear` to call `viewModel.onAppear()`
- [ ] Update `.onChange(of: chip.metadata)` to call `viewModel.onMetadataChanged()`

