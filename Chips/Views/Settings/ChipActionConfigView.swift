import SwiftUI
import CoreData
import Foundation

struct ChipActionConfigView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [
            NSSortDescriptor(keyPath: \ChipActionConfiguration.priority, ascending: false),
            NSSortDescriptor(keyPath: \ChipActionConfiguration.title, ascending: true)
        ],
        animation: .default
    )
    private var configurations: FetchedResults<ChipActionConfiguration>
    
    @State private var showingAddConfig = false
    @State private var editingConfig: ChipActionConfiguration?
    
    var body: some View {
        List {
            ForEach(configurations) { config in
                ConfigurationRow(config: config)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        editingConfig = config
                    }
            }
            .onDelete(perform: deleteConfigurations)
        }
        .navigationTitle("Action Configurations")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddConfig = true
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
        .sheet(isPresented: $showingAddConfig) {
            ConfigurationEditView(config: nil, context: viewContext)
        }
        .sheet(item: $editingConfig) { config in
            ConfigurationEditView(config: config, context: viewContext)
        }
    }
    
    private func deleteConfigurations(at offsets: IndexSet) {
        withAnimation {
            offsets.map { configurations[$0] }.forEach(viewContext.delete)
            try? viewContext.save()
        }
    }
}

struct ConfigurationRow: View {
    @ObservedObject var config: ChipActionConfiguration
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(config.title)
                    .font(.headline)
                
                Spacer()
                
                if !config.isEnabled {
                    Text("Disabled")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.2))
                        .clipShape(Capsule())
                }
            }
            
            if let summary = config.summary, !summary.isEmpty {
                Text(summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            HStack(spacing: 12) {
                Label(config.actionType.uppercased(), systemImage: actionIcon)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                if let pattern = config.urlPattern, !pattern.isEmpty {
                    Label(pattern, systemImage: "link")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                if !config.tagsArray.isEmpty {
                    Label(config.tagsArray.joined(separator: ", "), systemImage: "tag")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private var actionIcon: String {
        switch config.actionType {
        case "url": return "link"
        case "xcallback": return "arrow.triangle.2.circlepath"
        default: return "square"
        }
    }
}

struct ConfigurationEditView: View {
    @Environment(\.dismiss) private var dismiss
    let config: ChipActionConfiguration?
    let context: NSManagedObjectContext
    
    @State private var title: String = ""
    @State private var summary: String = ""
    @State private var description: String = ""
    @State private var urlPattern: String = ""
    @State private var actionType: String = "url"
    @State private var actionURL: String = ""
    @State private var xCallbackScheme: String = ""
    @State private var xCallbackPath: String = ""
    @State private var xCallbackParams: String = ""
    @State private var tags: String = ""
    @State private var isEnabled: Bool = true
    @State private var priority: Int32 = 0
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Basic Information") {
                    TextField("Title", text: $title)
                    TextField("Summary (optional)", text: $summary)
                    TextField("Description (optional)", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section("Matching") {
                    TextField("URL Pattern (e.g., youtube.com, *github.com/*)", text: $urlPattern)
                        .help("Match chips by URL pattern. Use * for wildcards.")
                    
                    TextField("Tags (comma-separated)", text: $tags)
                        .help("Match chips by tags. Leave empty to match all.")
                    
                    Stepper("Priority: \(priority)", value: $priority, in: -100...100)
                        .help("Higher priority configurations are checked first.")
                }
                
                Section("Action") {
                    Picker("Action Type", selection: $actionType) {
                        Text("URL").tag("url")
                        Text("x-callback-url").tag("xcallback")
                    }
                    
                    if actionType == "url" {
                        TextField("Action URL", text: $actionURL)
                            #if os(iOS)
                            .keyboardType(.URL)
                            .autocapitalization(.none)
                            #endif
                            .help("URL to open. Leave empty to use chip's original URL.")
                    } else if actionType == "xcallback" {
                        TextField("Scheme (e.g., myapp)", text: $xCallbackScheme)
                            #if os(iOS)
                            .autocapitalization(.none)
                            #endif
                        TextField("Path (optional)", text: $xCallbackPath)
                            #if os(iOS)
                            .autocapitalization(.none)
                            #endif
                        TextField("Parameters (JSON)", text: $xCallbackParams, axis: .vertical)
                            .lineLimit(3...6)
                            .font(.system(.body, design: .monospaced))
                            .help("JSON object with parameters. Use {{title}}, {{url}}, {{tags}} for placeholders.")
                    }
                }
                
                Section {
                    Toggle("Enabled", isOn: $isEnabled)
                }
            }
            .navigationTitle(config == nil ? "New Configuration" : "Edit Configuration")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
        .onAppear {
            loadConfig()
        }
    }
    
    private func loadConfig() {
        guard let config = config else {
            // New config - set defaults
            priority = 0
            isEnabled = true
            actionType = "url"
            return
        }
        
        title = config.title
        summary = config.summary ?? ""
        description = config.configDescription ?? ""
        urlPattern = config.urlPattern ?? ""
        actionType = config.actionType
        actionURL = config.actionURL ?? ""
        xCallbackScheme = config.xCallbackScheme ?? ""
        xCallbackPath = config.xCallbackPath ?? ""
        xCallbackParams = config.xCallbackParams ?? ""
        tags = config.tags ?? ""
        isEnabled = config.isEnabled
        priority = config.priority
    }
    
    private func save() {
        let configToSave: ChipActionConfiguration
        if let existing = config {
            configToSave = existing
        } else {
            configToSave = ChipActionConfiguration(context: context)
            configToSave.id = UUID()
            configToSave.createdAt = Date()
        }
        
        configToSave.title = title
        configToSave.summary = summary.isEmpty ? nil : summary
        configToSave.configDescription = description.isEmpty ? nil : description
        configToSave.urlPattern = urlPattern.isEmpty ? nil : urlPattern
        configToSave.actionType = actionType
        configToSave.actionURL = actionURL.isEmpty ? nil : actionURL
        configToSave.xCallbackScheme = xCallbackScheme.isEmpty ? nil : xCallbackScheme
        configToSave.xCallbackPath = xCallbackPath.isEmpty ? nil : xCallbackPath
        configToSave.xCallbackParams = xCallbackParams.isEmpty ? nil : xCallbackParams
        configToSave.tags = tags.isEmpty ? nil : tags
        configToSave.isEnabled = isEnabled
        configToSave.priority = priority
        
        do {
            try context.save()
            dismiss()
        } catch {
            print("Failed to save configuration: \(error)")
        }
    }
}

#Preview {
    ChipActionConfigView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}

