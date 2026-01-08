import SwiftUI
import CoreData

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

    @State private var showingAddSheet = false
    @State private var editingConfig: ChipActionConfiguration?

    var body: some View {
        List {
            if configurations.isEmpty {
                ContentUnavailableView {
                    Label("No Actions", systemImage: "bolt.slash")
                } description: {
                    Text("Add an action to send chips to other apps like NotePlan.")
                } actions: {
                    Button("Add Action") {
                        AppLogger.info("➕ Add Action button tapped", category: AppConstants.LoggerCategory.app)
                        showingAddSheet = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                ForEach(configurations) { config in
                    ActionRow(config: config)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            editingConfig = config
                        }
                }
                .onDelete(perform: deleteConfigurations)
            }
        }
        .navigationTitle("Actions")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    AppLogger.info("➕ Add Action toolbar button tapped", category: AppConstants.LoggerCategory.app)
                    showingAddSheet = true
                } label: {
                    Label("Add", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            #if os(macOS)
            AddActionSheet(context: viewContext)
                .frame(minWidth: 500, idealWidth: 600, maxWidth: .infinity, minHeight: 400, idealHeight: 500)
            #else
            AddActionSheet(context: viewContext)
            #endif
        }
        .sheet(item: $editingConfig) { config in
            EditActionSheet(config: config, context: viewContext)
        }
    }

    private func deleteConfigurations(at offsets: IndexSet) {
        withAnimation {
            offsets.map { configurations[$0] }.forEach(viewContext.delete)
            try? viewContext.save()
        }
    }
}

// MARK: - Action Row

struct ActionRow: View {
    @ObservedObject var config: ChipActionConfiguration

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconForConfig)
                .font(.title2)
                .foregroundStyle(config.isEnabled ? .blue : .secondary)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(config.title)
                        .font(.headline)

                    if !config.isEnabled {
                        Text("OFF")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.2))
                            .clipShape(Capsule())
                    }
                }

                HStack(spacing: 8) {
                    if let pattern = config.urlPattern, !pattern.isEmpty {
                        Label(pattern, systemImage: "link")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    let actionCount = config.actions.count
                    if actionCount > 1 {
                        Label("\(actionCount) actions", systemImage: "list.number")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }

    private var iconForConfig: String {
        if let scheme = config.xCallbackScheme?.lowercased() {
            switch scheme {
            case "noteplan": return "calendar.badge.plus"
            case "things": return "checkmark.circle"
            case "obsidian": return "doc.text"
            default: break
            }
        }
        return config.actionType == "xcallback" ? "arrow.triangle.2.circlepath" : "link"
    }
}

// MARK: - Add Action Sheet

struct AddActionSheet: View {
    @Environment(\.dismiss) private var dismiss
    let context: NSManagedObjectContext

    @State private var selectedPreset: ActionPreset?

    var body: some View {
        NavigationStack {
            Group {
                #if os(macOS)
                // Use ScrollView for macOS - more reliable than List with sections
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(alignment: .leading, spacing: 24) {
                        // Choose an App section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Choose an App")
                                .font(.headline)
                                .foregroundStyle(.primary)
                            
                            let presets = ActionPreset.all
                            if presets.isEmpty {
                                Text("No presets available")
                                    .foregroundStyle(.secondary)
                                    .font(.caption)
                            } else {
                                ForEach(presets) { preset in
                                    Button {
                                        AppLogger.info("🎯 Preset selected: \(preset.name) (id: \(preset.id))", category: AppConstants.LoggerCategory.app)
                                        selectedPreset = preset
                                    } label: {
                                        PresetRow(preset: preset)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            
                            Text("Select an app to configure how chips are sent to it.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        
                        // Advanced section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Advanced")
                                .font(.headline)
                                .foregroundStyle(.primary)
                            
                            Button {
                                createCustomConfig()
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "wrench.and.screwdriver")
                                        .font(.title2)
                                        .foregroundStyle(.orange)
                                        .frame(width: 32)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Custom Action")
                                            .font(.headline)
                                            .foregroundStyle(.primary)
                                        Text("Create your own x-callback-url action")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                }
                                .padding(.vertical, 4)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .padding()
                    .frame(minWidth: 500, maxWidth: .infinity)
                }
                .frame(minWidth: 500, idealWidth: 600, maxWidth: .infinity)
                #else
                List {
                    Section {
                        let presets = ActionPreset.all
                        
                        if presets.isEmpty {
                            Text("No presets available")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        } else {
                            ForEach(presets) { preset in
                                Button {
                                    AppLogger.info("🎯 Preset selected: \(preset.name) (id: \(preset.id))", category: AppConstants.LoggerCategory.app)
                                    selectedPreset = preset
                                } label: {
                                    PresetRow(preset: preset)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    } header: {
                        Text("Choose an App")
                    } footer: {
                        Text("Select an app to configure how chips are sent to it.")
                    }

                    Section {
                        Button {
                            createCustomConfig()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "wrench.and.screwdriver")
                                    .font(.title2)
                                    .foregroundStyle(.orange)
                                    .frame(width: 32)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Custom Action")
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    Text("Create your own x-callback-url action")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    } header: {
                        Text("Advanced")
                    }
                }
                #endif
            }
            .navigationTitle("Add Action")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            #if os(macOS)
            .frame(minWidth: 500, idealWidth: 600, maxWidth: .infinity)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { 
                        AppLogger.info("❌ AddActionSheet cancelled", category: AppConstants.LoggerCategory.app)
                        dismiss() 
                    }
                }
            }
            .sheet(item: $selectedPreset) { preset in
                ConfigurePresetSheet(preset: preset, context: context) {
                    AppLogger.info("✅ ConfigurePresetSheet completed for: \(preset.name)", category: AppConstants.LoggerCategory.app)
                    dismiss()
                }
            }
            .onAppear {
                AppLogger.info("📱 AddActionSheet appeared", category: AppConstants.LoggerCategory.app)
                let presets = ActionPreset.all
                if presets.isEmpty {
                    AppLogger.warning("⚠️ No presets available", category: AppConstants.LoggerCategory.app)
                } else {
                    AppLogger.info("📋 Found \(presets.count) presets", category: AppConstants.LoggerCategory.app)
                }
            }
        }
    }

    private func createCustomConfig() {
        AppLogger.info("🔧 Creating custom config", category: AppConstants.LoggerCategory.app)
        let config = ChipActionConfiguration(context: context)
        config.id = UUID()
        config.title = "Custom Action"
        config.actionType = "xcallback"
        config.isEnabled = true
        config.priority = 0
        config.createdAt = Date()
        do {
            try context.save()
            AppLogger.info("✅ Custom config created successfully", category: AppConstants.LoggerCategory.app)
        } catch {
            AppLogger.error("❌ Failed to save custom config: \(error.localizedDescription)", category: AppConstants.LoggerCategory.app)
        }
        dismiss()
    }
}

struct PresetRow: View {
    let preset: ActionPreset

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: preset.icon)
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(preset.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(preset.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Configure Preset Sheet

struct ConfigurePresetSheet: View {
    @Environment(\.dismiss) private var dismiss
    let preset: ActionPreset
    let context: NSManagedObjectContext
    let onComplete: () -> Void

    // Source URL configuration
    @State private var urlPattern: String = ""
    @State private var sampleSourceURL: String = ""

    // Template configuration
    @State private var textTemplate: String = ""
    @State private var selectedTemplateIndex: Int = 0
    @State private var showVariableAutocomplete: Bool = false
    @State private var autocompleteAnchor: CGRect = .zero

    // Additional options
    @State private var alsoOpenOriginalURL: Bool = true
    @State private var isEnabled: Bool = true

    // Sample data for preview
    @State private var sampleTitle: String = "Sample Video Title"
    
    // Detect source type from sample URL
    private var detectedSourceType: URLVariableExtractor.ExtractedVariables.SourceType {
        let url = sampleSourceURL.isEmpty ? "https://youtube.com/watch?v=dQw4w9WgXcQ" : sampleSourceURL
        return URLVariableExtractor.extract(from: url, chipTitle: sampleTitle).sourceType
    }

    private var extractedVariables: URLVariableExtractor.ExtractedVariables {
        let url = sampleSourceURL.isEmpty ? "https://youtube.com/watch?v=dQw4w9WgXcQ" : sampleSourceURL
        return URLVariableExtractor.extract(from: url, chipTitle: sampleTitle)
    }

    private var templateSuggestions: [String] {
        switch detectedSourceType {
        case .youtube:
            return [
                "- [ ] {{title}} {{url}}",
                "- [ ] Watch: {{title}} {{url}}",
                "- [ ] 🎬 {{title}} ({{video_id}})\n  {{url}}",
                "- [ ] {{title}} #youtube #video"
            ]
        case .github:
            return [
                "- [ ] {{title}} {{url}}",
                "- [ ] Review: {{owner}}/{{repo}} {{url}}",
                "- [ ] 💻 {{repo}}: {{title}}\n  {{url}}",
                "- [ ] {{title}} #github #code"
            ]
        case .twitter:
            return [
                "- [ ] {{title}} {{url}}",
                "- [ ] Tweet by @{{username}} {{url}}",
                "- [ ] 🐦 {{title}}\n  {{url}}",
                "- [ ] {{title}} #twitter"
            ]
        case .spotify:
            return [
                "- [ ] {{title}} {{url}}",
                "- [ ] Listen: {{title}} {{url}}",
                "- [ ] 🎵 {{title}} ({{type}})\n  {{url}}",
                "- [ ] {{title}} #spotify #music"
            ]
        case .generic:
            return [
                "- [ ] {{title}} {{url}}",
                "- [ ] Read: {{title}} {{url}}",
                "- [ ] 🔗 {{title}} ({{host}})\n  {{url}}",
                "- [ ] {{title}} #link"
            ]
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                // Preset header
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: preset.icon)
                            .font(.largeTitle)
                            .foregroundStyle(.blue)

                        VStack(alignment: .leading) {
                            Text(preset.name)
                                .font(.headline)
                            Text(preset.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .listRowBackground(Color.clear)
                }

                // Source URL Section
                Section {
                    TextField("URL pattern to match (e.g., youtube.com)", text: $urlPattern)
                        .font(.system(.body, design: .monospaced))
                        #if os(iOS)
                        .autocapitalization(.none)
                        .keyboardType(.URL)
                        #endif

                    // Sample URL for preview
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Sample URL for preview:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("Sample URL", text: $sampleSourceURL)
                            .font(.system(.caption, design: .monospaced))
                            #if os(iOS)
                            .autocapitalization(.none)
                            .keyboardType(.URL)
                            #endif
                    }
                } header: {
                    Text("URL Pattern")
                } footer: {
                    Text("Chips with URLs containing \"\(urlPattern.isEmpty ? "youtube.com" : urlPattern)\" will trigger this action.")
                }

                // Template Section
                Section {
                    // Template suggestions
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Array(templateSuggestions.enumerated()), id: \.offset) { index, suggestion in
                                Button {
                                    textTemplate = suggestion
                                    selectedTemplateIndex = index
                                } label: {
                                    Text(suggestion.components(separatedBy: "\n").first ?? suggestion)
                                        .font(.caption)
                                        .lineLimit(1)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(selectedTemplateIndex == index ? Color.blue : Color.secondary.opacity(0.2))
                                        .foregroundStyle(selectedTemplateIndex == index ? .white : .primary)
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))

                    HStack {
                        TextEditor(text: $textTemplate)
                            .font(.system(.body, design: .monospaced))
                            .frame(minHeight: 80)
                        
                        Button {
                            showVariableAutocomplete.toggle()
                        } label: {
                            Image(systemName: "info.circle")
                                .foregroundStyle(.blue)
                        }
                        .buttonStyle(.plain)
                        .help("Show available variables")
                    }
                } header: {
                    Text("Task Text Template")
                } footer: {
                    HStack {
                        Text("Use {{variable}} syntax. Click")
                        Button {
                            showVariableAutocomplete.toggle()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "info.circle")
                                Text("for available variables")
                            }
                            .font(.caption)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .popover(isPresented: $showVariableAutocomplete) {
                    VariableAutocompleteView(
                        sourceType: detectedSourceType,
                        extractedVariables: extractedVariables
                    )
                    .frame(width: 400, height: 300)
                }

                // Preview Section
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        // Resolved text preview
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Task text:")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(resolvedTemplate)
                                .font(.system(.caption, design: .monospaced))
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.secondary.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }

                        // Full xcallback URL preview
                        VStack(alignment: .leading, spacing: 4) {
                            Text("x-callback-url:")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(xcallbackURLPreview)
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(.blue)
                                .lineLimit(3)
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.blue.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }

                        if alsoOpenOriginalURL {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Then opens:")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(sampleSourceURL.isEmpty ? "https://youtube.com/watch?v=dQw4w9WgXcQ" : sampleSourceURL)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(.green)
                                    .lineLimit(1)
                            }
                        }
                    }
                } header: {
                    Text("Preview")
                }

                // Additional Actions
                Section {
                    Toggle("Also open the original URL", isOn: $alsoOpenOriginalURL)
                } header: {
                    Text("Additional Actions")
                } footer: {
                    Text("Opens the chip's URL after adding to \(preset.name.components(separatedBy: " - ").first ?? preset.name).")
                }

                Section {
                    Toggle("Enabled", isOn: $isEnabled)
                }
            }
            .navigationTitle("Configure Action")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveConfiguration()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                setupDefaults()
            }
        }
    }

    private var resolvedTemplate: String {
        URLVariableExtractor.resolve(template: textTemplate, with: extractedVariables.variables)
    }

    private var xcallbackURLPreview: String {
        var components = URLComponents()
        components.scheme = preset.scheme
        components.host = "x-callback-url"
        components.path = "/\(preset.path)"

        var queryItems: [URLQueryItem] = []
        for (key, value) in preset.defaultParams {
            queryItems.append(URLQueryItem(name: key, value: value))
        }
        queryItems.append(URLQueryItem(name: "text", value: resolvedTemplate))
        components.queryItems = queryItems

        return components.url?.absoluteString ?? "Invalid URL"
    }

    private func setupDefaults() {
        // Set default URL pattern
        urlPattern = "youtube.com"
        sampleSourceURL = "https://youtube.com/watch?v=dQw4w9WgXcQ"
        textTemplate = preset.templateText ?? templateSuggestions.first ?? "- [ ] {{title}} {{url}}"
    }

    private func saveConfiguration() {
        let config = ChipActionConfiguration(context: context)
        config.id = UUID()
        config.title = preset.name
        config.summary = preset.description
        config.urlPattern = urlPattern.isEmpty ? nil : urlPattern
        config.actionType = "xcallback"
        config.xCallbackScheme = preset.scheme
        config.xCallbackPath = preset.path
        config.isEnabled = isEnabled
        config.priority = 0
        config.createdAt = Date()

        // Build actions array
        var actions: [ChipActionItem] = []

        // Primary action
        var params = preset.defaultParams
        params["text"] = textTemplate
        actions.append(ChipActionItem(
            id: UUID(),
            type: .xcallback,
            name: preset.name,
            scheme: preset.scheme,
            path: preset.path,
            params: params,
            template: textTemplate
        ))

        // Optional: open original URL
        if alsoOpenOriginalURL {
            actions.append(.openOriginal)
        }

        config.actions = actions

        // Legacy fields
        if let jsonData = try? JSONSerialization.data(withJSONObject: params),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            config.xCallbackParams = jsonString
        }

        try? context.save()
        onComplete()
        dismiss()
    }
}

// MARK: - Edit Action Sheet

struct EditActionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var config: ChipActionConfiguration
    let context: NSManagedObjectContext

    @State private var title: String = ""
    @State private var urlPattern: String = ""
    @State private var actions: [ChipActionItem] = []
    @State private var isEnabled: Bool = true
    @State private var showDeleteConfirm = false
    @State private var showAddAction = false
    @State private var editingActionIndex: Int?

    // Preview
    @State private var sampleURL: String = "https://youtube.com/watch?v=dQw4w9WgXcQ"
    @State private var sampleTitle: String = "Sample Video"

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $title)
                }

                Section {
                    TextField("URL pattern", text: $urlPattern)
                        .font(.system(.body, design: .monospaced))
                        #if os(iOS)
                        .autocapitalization(.none)
                        #endif
                } header: {
                    Text("Match URLs Containing")
                }

                Section {
                    ForEach(Array(actions.enumerated()), id: \.element.id) { index, action in
                        ActionItemEditRow(action: action) {
                            editingActionIndex = index
                        }
                    }
                    .onDelete(perform: deleteActions)
                    .onMove(perform: moveActions)

                    Button {
                        showAddAction = true
                    } label: {
                        Label("Add Action", systemImage: "plus.circle")
                    }
                } header: {
                    Text("Actions (in order)")
                } footer: {
                    Text("Actions execute sequentially when a matching chip is tapped.")
                }

                // Preview section
                if !actions.isEmpty {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            TextField("Sample URL", text: $sampleURL)
                                .font(.system(.caption, design: .monospaced))
                                #if os(iOS)
                                .autocapitalization(.none)
                                #endif

                            ForEach(Array(actions.enumerated()), id: \.element.id) { index, action in
                                let preview = previewAction(action)
                                HStack(alignment: .top) {
                                    Text("\(index + 1).")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(action.name)
                                            .font(.caption)
                                            .fontWeight(.medium)
                                        Text(preview)
                                            .font(.system(.caption2, design: .monospaced))
                                            .foregroundStyle(.blue)
                                            .lineLimit(2)
                                    }
                                }
                            }
                        }
                    } header: {
                        Text("Preview")
                    }
                }

                Section {
                    Toggle("Enabled", isOn: $isEnabled)
                }

                Section {
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        HStack {
                            Spacer()
                            Text("Delete Configuration")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Edit Action")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }
            }
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                    }
                    .fontWeight(.semibold)
                }
            }
            .alert("Delete Configuration?", isPresented: $showDeleteConfirm) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    context.delete(config)
                    try? context.save()
                    dismiss()
                }
            } message: {
                Text("This cannot be undone.")
            }
            .sheet(isPresented: $showAddAction) {
                AddActionItemSheet { newAction in
                    actions.append(newAction)
                }
            }
            .sheet(item: $editingActionIndex) { index in
                EditActionItemSheet(action: $actions[index])
            }
            .onAppear {
                loadConfig()
            }
        }
    }

    private func previewAction(_ action: ChipActionItem) -> String {
        let extracted = URLVariableExtractor.extract(from: sampleURL, chipTitle: sampleTitle)

        switch action.type {
        case .openOriginal:
            return sampleURL
        case .openURL:
            return action.targetURL ?? sampleURL
        case .xcallback:
            if let template = action.template {
                return URLVariableExtractor.resolve(template: template, with: extracted.variables)
            }
            return "\(action.scheme ?? "")://x-callback-url/\(action.path ?? "")"
        }
    }

    private func loadConfig() {
        title = config.title
        urlPattern = config.urlPattern ?? ""
        isEnabled = config.isEnabled
        actions = config.actions
    }

    private func saveChanges() {
        config.title = title
        config.urlPattern = urlPattern.isEmpty ? nil : urlPattern
        config.isEnabled = isEnabled
        config.actions = actions

        try? context.save()
        dismiss()
    }

    private func deleteActions(at offsets: IndexSet) {
        actions.remove(atOffsets: offsets)
    }

    private func moveActions(from source: IndexSet, to destination: Int) {
        actions.move(fromOffsets: source, toOffset: destination)
    }
}

// MARK: - Action Item Edit Row

struct ActionItemEditRow: View {
    let action: ChipActionItem
    let onEdit: () -> Void

    var body: some View {
        Button(action: onEdit) {
            HStack(spacing: 12) {
                Image(systemName: iconForAction)
                    .foregroundStyle(.blue)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(action.name)
                        .font(.subheadline)
                        .foregroundStyle(.primary)

                    if let template = action.template {
                        Text(template)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    } else if action.type == .openOriginal {
                        Text("Opens chip's original URL")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var iconForAction: String {
        switch action.type {
        case .openOriginal: return "link"
        case .openURL: return "globe"
        case .xcallback:
            switch action.scheme?.lowercased() {
            case "noteplan": return "calendar.badge.plus"
            case "things": return "checkmark.circle"
            case "obsidian": return "doc.text"
            default: return "arrow.triangle.2.circlepath"
            }
        }
    }
}

// MARK: - Edit Action Item Sheet

struct EditActionItemSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var action: ChipActionItem

    @State private var template: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("Type")
                        Spacer()
                        Text(action.type.rawValue)
                            .foregroundStyle(.secondary)
                    }

                    if action.type == .xcallback {
                        HStack {
                            Text("Scheme")
                            Spacer()
                            Text(action.scheme ?? "-")
                                .foregroundStyle(.secondary)
                        }

                        HStack {
                            Text("Path")
                            Spacer()
                            Text(action.path ?? "-")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if action.type == .xcallback {
                    Section {
                        TextEditor(text: $template)
                            .font(.system(.body, design: .monospaced))
                            .frame(minHeight: 100)
                    } header: {
                        Text("Template")
                    } footer: {
                        Text("Use {{title}}, {{url}}, {{video_id}}, etc.")
                    }
                }
            }
            .navigationTitle("Edit Action")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        action.template = template
                        dismiss()
                    }
                }
            }
            .onAppear {
                template = action.template ?? ""
            }
        }
    }
}

// MARK: - Add Action Item Sheet

struct AddActionItemSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onAdd: (ChipActionItem) -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        onAdd(.openOriginal)
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "link")
                                .font(.title2)
                                .foregroundStyle(.blue)
                                .frame(width: 32)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Open Original URL")
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text("Opens the chip's URL in browser/app")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("Common")
                }

                Section {
                    ForEach(ActionPreset.all) { preset in
                        Button {
                            onAdd(.from(preset: preset))
                            dismiss()
                        } label: {
                            PresetRow(preset: preset)
                        }
                    }
                } header: {
                    Text("App Actions")
                }
            }
            .navigationTitle("Add Action")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Int Identifiable for Sheet

extension Int: @retroactive Identifiable {
    public var id: Int { self }
}

// MARK: - Identifiable for ActionPreset

extension ActionPreset: Hashable {
    static func == (lhs: ActionPreset, rhs: ActionPreset) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Variable Autocomplete View

struct VariableAutocompleteView: View {
    let sourceType: URLVariableExtractor.ExtractedVariables.SourceType
    let extractedVariables: URLVariableExtractor.ExtractedVariables
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Available Variables")
                    .font(.headline)
                    .padding(.bottom, 4)
                
                Text("Use these variables in your template with {{variable}} syntax:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Divider()
                
                let variables = URLVariableExtractor.ExtractedVariables.availableVariables(for: sourceType)
                ForEach(variables, id: \.key) { variable in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("{{\(variable.key)}}")
                                .font(.system(.body, design: .monospaced))
                                .foregroundStyle(.blue)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                            
                            Spacer()
                        }
                        
                        Text(variable.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        if let value = extractedVariables.variables[variable.key], !value.isEmpty {
                            Text("Example: \(value)")
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(.tertiary)
                                .padding(.leading, 8)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding()
        }
    }
}

#Preview {
    NavigationStack {
        ChipActionConfigView()
    }
    .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
