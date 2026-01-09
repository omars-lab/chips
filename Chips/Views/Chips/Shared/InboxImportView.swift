import SwiftUI
import CoreData

/// Shared component for importing inbox items
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
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
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

