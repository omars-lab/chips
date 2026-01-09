#if os(macOS)
import SwiftUI
import CoreData

/// macOS-specific implementation of ChipsTabView
struct ChipsTabView_macOS: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject private var viewModel: ChipsTabViewModel
    @ObservedObject private var timerManager = TimerManager.shared
    @ObservedObject private var inboxMonitor = InboxMonitor.shared

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \ChipSource.name, ascending: true)],
        animation: .default
    )
    private var sources: FetchedResults<ChipSource>

    init(viewModel: ChipsTabViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Group {
                    if sources.isEmpty {
                        EmptySourcesView(showingSourcePicker: $viewModel.showingSourcePicker)
                    } else {
                        ChipListView(
                            source: viewModel.selectedSource ?? sources.first,
                            searchText: viewModel.searchText,
                            useGridLayout: true  // Grid layout on Mac
                        )
                    }
                }

                // Floating timer overlay
                FloatingTimerView(timerManager: timerManager)
            }
            .navigationTitle("Chips")
            .searchable(text: $viewModel.searchText, prompt: "Search chips")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        ForEach(sources) { source in
                            Button {
                                viewModel.selectedSource = source
                            } label: {
                                Label(
                                    source.unwrappedName,
                                    systemImage: viewModel.selectedSource == source ? "checkmark" : ""
                                )
                            }
                        }

                        Divider()

                        Button {
                            viewModel.showingSourcePicker = true
                        } label: {
                            Label("Add Source...", systemImage: "plus")
                        }
                    } label: {
                        Label("Sources", systemImage: "doc.text")
                    }
                    .keyboardShortcut("n", modifiers: .command)
                }

                // Inbox button with badge
                if inboxMonitor.pendingItemsCount > 0 {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            viewModel.showingInboxSheet = true
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
                        .keyboardShortcut("i", modifiers: .command)
                    }
                }

                ToolbarItem(placement: .automatic) {
                    FilterMenu()
                }
            }
            .sheet(isPresented: $viewModel.showingSourcePicker) {
                FolderPickerView {
                    if viewModel.selectedSource == nil {
                        viewModel.selectedSource = sources.first
                    }
                }
                .frame(minWidth: 500, idealWidth: 600, maxWidth: .infinity, minHeight: 400, idealHeight: 500, maxHeight: .infinity)
            }
            .sheet(isPresented: $viewModel.showingInboxSheet) {
                InboxImportView(selectedSource: $viewModel.selectedSource)
                    .frame(minWidth: 500, idealWidth: 600, maxWidth: .infinity, minHeight: 400, idealHeight: 500, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 600, minHeight: 400)
        .onAppear {
            if viewModel.selectedSource == nil {
                viewModel.selectedSource = sources.first
            }
            inboxMonitor.checkForNewItems()
        }
    }
}
#endif
