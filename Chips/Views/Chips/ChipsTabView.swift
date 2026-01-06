import SwiftUI
import CoreData

struct ChipsTabView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @StateObject private var viewModel = ChipsViewModel()
    @ObservedObject private var timerManager = TimerManager.shared
    @ObservedObject private var inboxMonitor = InboxMonitor.shared

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \ChipSource.name, ascending: true)],
        animation: .default
    )
    private var sources: FetchedResults<ChipSource>

    @State private var selectedSource: ChipSource?
    @State private var showingSourcePicker = false
    @State private var showingInboxSheet = false
    @State private var searchText = ""

    private var useGridLayout: Bool {
        #if os(macOS)
        return true
        #else
        return horizontalSizeClass == .regular
        #endif
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Group {
                    if sources.isEmpty {
                        EmptySourcesView(showingSourcePicker: $showingSourcePicker)
                    } else {
                        ChipListView(
                            source: selectedSource ?? sources.first,
                            searchText: searchText,
                            useGridLayout: useGridLayout
                        )
                    }
                }

                // Floating timer overlay
                FloatingTimerView(timerManager: timerManager)
            }
            .navigationTitle("Chips")
            .searchable(text: $searchText, prompt: "Search chips")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        ForEach(sources) { source in
                            Button {
                                selectedSource = source
                            } label: {
                                Label(
                                    source.unwrappedName,
                                    systemImage: selectedSource == source ? "checkmark" : ""
                                )
                            }
                        }

                        Divider()

                        Button {
                            showingSourcePicker = true
                        } label: {
                            Label("Add Source...", systemImage: "plus")
                        }
                    } label: {
                        Label("Sources", systemImage: "doc.text")
                    }
                }

                // Inbox button with badge
                if inboxMonitor.pendingItemsCount > 0 {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            showingInboxSheet = true
                        } label: {
                            ZStack(alignment: .topTrailing) {
                                Image(systemName: "tray.and.arrow.down")
                                Text("\(inboxMonitor.pendingItemsCount)")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.white)
                                    .padding(4)
                                    .background(Color.red)
                                    .clipShape(Circle())
                                    .offset(x: 8, y: -8)
                            }
                        }
                    }
                }

                #if os(iOS)
                ToolbarItem(placement: .topBarLeading) {
                    FilterMenu()
                }
                #else
                ToolbarItem(placement: .automatic) {
                    FilterMenu()
                }
                #endif
            }
            .sheet(isPresented: $showingSourcePicker) {
                FolderPickerView {
                    if selectedSource == nil {
                        selectedSource = sources.first
                    }
                }
            }
            .sheet(isPresented: $showingInboxSheet) {
                InboxImportView(selectedSource: $selectedSource)
            }
        }
        .onAppear {
            if selectedSource == nil {
                selectedSource = sources.first
            }
            inboxMonitor.checkForNewItems()
        }
    }
}

// MARK: - Inbox Import View
struct InboxImportView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var inboxMonitor = InboxMonitor.shared
    @Binding var selectedSource: ChipSource?

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \ChipSource.name, ascending: true)],
        animation: .default
    )
    private var sources: FetchedResults<ChipSource>

    @State private var targetSource: ChipSource?
    @State private var newSourceName = ""
    @State private var importError: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if let preview = inboxMonitor.previewContent() {
                        Text(preview)
                            .font(.system(.caption, design: .monospaced))
                            .lineLimit(10)
                    }
                } header: {
                    Text("Shared Items (\(inboxMonitor.pendingItemsCount))")
                }

                Section("Import to") {
                    Picker("Source", selection: $targetSource) {
                        Text("New Source...").tag(nil as ChipSource?)
                        ForEach(sources) { source in
                            Text(source.unwrappedName).tag(source as ChipSource?)
                        }
                    }

                    if targetSource == nil {
                        TextField("New source name", text: $newSourceName)
                    }
                }

                if let error = importError {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Import Shared Items")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Import") {
                        importItems()
                    }
                    .disabled(targetSource == nil && newSourceName.isEmpty)
                }
            }
        }
    }

    private func importItems() {
        do {
            if let source = targetSource {
                _ = try inboxMonitor.importItems(to: source, context: viewContext)
                selectedSource = source
            } else if !newSourceName.isEmpty {
                let (source, _) = try inboxMonitor.importToNewSource(named: newSourceName, context: viewContext)
                selectedSource = source
            }
            dismiss()
        } catch {
            importError = error.localizedDescription
        }
    }
}

// MARK: - Empty State
struct EmptySourcesView: View {
    @Binding var showingSourcePicker: Bool

    var body: some View {
        ContentUnavailableView {
            Label("No Sources", systemImage: "doc.text.magnifyingglass")
        } description: {
            Text("Add a folder from iCloud Drive containing your markdown files.")
        } actions: {
            Button("Add Source") {
                showingSourcePicker = true
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

// MARK: - Chip List
struct ChipListView: View {
    let source: ChipSource?
    let searchText: String
    let useGridLayout: Bool

    @Environment(\.managedObjectContext) private var viewContext

    var chips: [Chip] {
        guard let source = source else { return [] }
        var result = source.chipsArray

        if !searchText.isEmpty {
            result = result.filter {
                $0.unwrappedTitle.localizedCaseInsensitiveContains(searchText)
            }
        }

        return result
    }

    var groupedChips: [(String, [Chip])] {
        let grouped = Dictionary(grouping: chips) { $0.sectionTitle ?? "General" }
        return grouped.sorted { $0.key < $1.key }
    }

    var body: some View {
        if chips.isEmpty {
            if searchText.isEmpty {
                ContentUnavailableView(
                    "No Chips",
                    systemImage: "square.grid.2x2",
                    description: Text("Chips from your markdown files will appear here.")
                )
            } else {
                ContentUnavailableView.search(text: searchText)
            }
        } else if useGridLayout {
            // Grid layout for iPad/Mac
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24) {
                    ForEach(groupedChips, id: \.0) { section, sectionChips in
                        VStack(alignment: .leading, spacing: 12) {
                            Text(section)
                                .font(.title2)
                                .fontWeight(.semibold)
                                .padding(.horizontal)

                            ChipGridView(chips: sectionChips, sectionTitle: section)
                        }
                    }
                }
                .padding(.vertical)
            }
            #if os(iOS)
            .background(Color(uiColor: .systemGroupedBackground))
            #else
            .background(Color(nsColor: .windowBackgroundColor))
            #endif
        } else {
            // List layout for iPhone
            List {
                ForEach(groupedChips, id: \.0) { section, sectionChips in
                    Section(section) {
                        ForEach(sectionChips) { chip in
                            ChipRowView(chip: chip)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
    }
}

// MARK: - Filter Menu
struct FilterMenu: View {
    @State private var showCompleted = true
    @State private var selectedTags: Set<String> = []

    var body: some View {
        Menu {
            Toggle("Show Completed", isOn: $showCompleted)

            Divider()

            Menu("Tags") {
                Button("All Tags") {
                    selectedTags.removeAll()
                }
                // Tags would be populated dynamically
            }
        } label: {
            Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
        }
    }
}

#Preview {
    ChipsTabView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
