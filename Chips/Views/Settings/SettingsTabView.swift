import SwiftUI

struct SettingsTabView: View {
    @AppStorage("defaultApp") private var defaultApp = "safari"
    @AppStorage("showCompletedChips") private var showCompletedChips = true
    @AppStorage("chipLayoutStyle") private var chipLayoutStyle = "list"

    var body: some View {
        NavigationStack {
            List {
                // Sources Section
                Section {
                    NavigationLink {
                        SourcesSettingsView()
                    } label: {
                        Label("Markdown Sources", systemImage: "folder")
                    }
                } header: {
                    Text("Sources")
                } footer: {
                    Text("Manage folders containing your markdown files.")
                }

                // Appearance Section
                Section("Appearance") {
                    Picker("Chip Layout", selection: $chipLayoutStyle) {
                        Text("List").tag("list")
                        Text("Grid").tag("grid")
                    }

                    Toggle("Show Completed Chips", isOn: $showCompletedChips)
                }

                // Actions Section
                Section {
                    NavigationLink {
                        ChipActionConfigView()
                    } label: {
                        Label("Action Configurations", systemImage: "gearshape.2")
                    }
                    
                    Picker("Default App for URLs", selection: $defaultApp) {
                        Text("Safari").tag("safari")
                        Text("YouTube").tag("youtube")
                        Text("In-App Browser").tag("inapp")
                    }
                } header: {
                    Text("Actions")
                } footer: {
                    Text("Configure custom actions for chips based on URL patterns or tags.")
                }

                // Sync Section
                Section {
                    NavigationLink {
                        SyncStatusView()
                    } label: {
                        Label("iCloud Sync", systemImage: "icloud")
                    }
                } header: {
                    Text("Sync")
                } footer: {
                    Text("Your chips and history sync automatically across all your devices.")
                }

                // Export Section
                Section("Data") {
                    Button {
                        exportHistory()
                    } label: {
                        Label("Export History", systemImage: "square.and.arrow.up")
                    }
                }

                // About Section
                Section("About") {
                    LabeledContent("Version", value: appVersion)

                    Link(destination: URL(string: "https://github.com/omars-lab/chips")!) {
                        Label("GitHub", systemImage: "link")
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    private func exportHistory() {
        // TODO: Implement export functionality
    }
}

// MARK: - Sources Settings
struct SourcesSettingsView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \ChipSource.name, ascending: true)],
        animation: .default
    )
    private var sources: FetchedResults<ChipSource>

    @State private var showingAddSource = false

    var body: some View {
        List {
            ForEach(sources) { source in
                VStack(alignment: .leading, spacing: 4) {
                    Text(source.unwrappedName)
                        .font(.headline)

                    Text(source.unwrappedPath)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let lastParsed = source.lastParsed {
                        Text("Last updated: \(lastParsed, style: .relative) ago")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.vertical, 4)
            }
            .onDelete(perform: deleteSources)
        }
        .navigationTitle("Sources")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddSource = true
                } label: {
                    Label("Add", systemImage: "plus")
                }
            }

            #if os(iOS)
            ToolbarItem(placement: .topBarLeading) {
                EditButton()
            }
            #endif
        }
        .sheet(isPresented: $showingAddSource) {
            FolderPickerView {
                // Refresh sources after adding
            }
        }
    }

    private func deleteSources(at offsets: IndexSet) {
        withAnimation {
            offsets.map { sources[$0] }.forEach(viewContext.delete)
            try? viewContext.save()
        }
    }
}

// MARK: - Sync Status
struct SyncStatusView: View {
    @State private var syncStatus: SyncStatus = .synced
    @State private var lastSyncDate: Date? = Date()

    var body: some View {
        List {
            Section {
                HStack {
                    Image(systemName: syncStatus.icon)
                        .foregroundStyle(syncStatus.color)
                    Text(syncStatus.description)
                }

                if let lastSync = lastSyncDate {
                    LabeledContent("Last Sync", value: lastSync, format: .relative(presentation: .named))
                }
            }

            Section {
                Button("Refresh Now") {
                    refreshSync()
                }
            }

            Section {
                LabeledContent("Account", value: "iCloud")
                LabeledContent("Container", value: "iCloud.com.chips.app")
            } header: {
                Text("Details")
            }
        }
        .navigationTitle("iCloud Sync")
    }

    private func refreshSync() {
        syncStatus = .syncing
        // Trigger sync refresh
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            syncStatus = .synced
            lastSyncDate = Date()
        }
    }
}

enum SyncStatus {
    case synced
    case syncing
    case error
    case offline

    var icon: String {
        switch self {
        case .synced: return "checkmark.icloud"
        case .syncing: return "arrow.triangle.2.circlepath.icloud"
        case .error: return "exclamationmark.icloud"
        case .offline: return "icloud.slash"
        }
    }

    var color: Color {
        switch self {
        case .synced: return .green
        case .syncing: return .blue
        case .error: return .red
        case .offline: return .gray
        }
    }

    var description: String {
        switch self {
        case .synced: return "Up to date"
        case .syncing: return "Syncing..."
        case .error: return "Sync error"
        case .offline: return "Offline"
        }
    }
}

#Preview {
    SettingsTabView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
