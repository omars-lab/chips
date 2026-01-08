import SwiftUI
#if os(macOS)
import AppKit
#endif

@MainActor
struct ChipRowView: View {
    @ObservedObject var chip: Chip
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject private var actionEngine = ActionEngine.shared
    @ObservedObject private var timerManager = TimerManager.shared
    
    // Use shared ViewModel for metadata and summary logic
    @StateObject private var viewModel: ChipViewModel

    @State private var showingHistory = false
    @State private var isPressed = false

    private var isActiveTimer: Bool {
        timerManager.activeTimer?.chipID == chip.id
    }
    
    init(chip: Chip) {
        self.chip = chip
        // Initialize ViewModel with chip's context or shared context
        let context = chip.managedObjectContext ?? PersistenceController.shared.container.viewContext
        _viewModel = StateObject(wrappedValue: ChipViewModel(chip: chip, context: context))
    }

    var body: some View {
        #if os(macOS)
        Button(action: {
            AppLogger.info("🖱️ Chip button tapped: \(chip.unwrappedTitle)", category: AppConstants.LoggerCategory.chipRowView)
            
            // Execute action first (to reduce latency)
            executeAction()
            
            // Fetch metadata last, only if not present
            Task {
                await viewModel.checkAndFetchMetadata()
            }
        }) {
            chipContent
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isActiveTimer ? Color.accentColor.opacity(0.1) : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isActiveTimer ? Color.accentColor : Color.clear, lineWidth: 2)
                )
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing) {
            Button {
                toggleCompleted()
            } label: {
                Label(
                    chip.isCompleted ? "Uncomplete" : "Complete",
                    systemImage: chip.isCompleted ? "arrow.uturn.backward" : "checkmark"
                )
            }
            .tint(chip.isCompleted ? .orange : .green)
        }
        .swipeActions(edge: .leading) {
            Button {
                showingHistory = true
            } label: {
                Label("History", systemImage: "clock")
            }
            .tint(.blue)
        }
        .contextMenu {
            Button {
                // Log when context menu button is clicked (confirms menu was built)
                let urlFromActionData = chip.actionData?.url
                let urlFromTitle = chip.unwrappedTitle.extractURL()
                let hasURLValue = urlFromActionData != nil || urlFromTitle != nil
                
                AppLogger.info("📋 [ChipRowView] Context menu 'Open' clicked for chip '\(chip.unwrappedTitle)'", category: AppConstants.LoggerCategory.chipRowView)
                AppLogger.info("   - actionData?.url: \(urlFromActionData ?? "nil")", category: AppConstants.LoggerCategory.chipRowView)
                AppLogger.info("   - URL from title: \(urlFromTitle ?? "nil")", category: AppConstants.LoggerCategory.chipRowView)
                AppLogger.info("   - hasURL: \(hasURLValue)", category: AppConstants.LoggerCategory.chipRowView)
                
                executeAction()
            } label: {
                Label("Open", systemImage: "arrow.up.right")
            }

            Button {
                showingHistory = true
            } label: {
                Label("View History", systemImage: "clock")
            }

            Divider()

            Button {
                toggleCompleted()
            } label: {
                Label(
                    chip.isCompleted ? "Mark as Active" : "Mark as Complete",
                    systemImage: chip.isCompleted ? "arrow.uturn.backward" : "checkmark"
                )
            }
            
            Divider()
            
            // Show metadata and summary options if chip has a URL (in actionData or title)
            if viewModel.hasURL {
                Button {
                    AppLogger.info("🖱️ [ChipRowView] 'View Metadata' button clicked", category: AppConstants.LoggerCategory.chipRowView)
                    Task {
                        await viewModel.fetchAndShowMetadata()
                    }
                } label: {
                    Label(
                        viewModel.isFetchingMetadata ? "Fetching..." : "View Metadata",
                        systemImage: "info.circle"
                    )
                }
                .disabled(viewModel.isFetchingMetadata)
                
                Button {
                    Task {
                        await viewModel.generateSummary()
                    }
                } label: {
                    Label(
                        viewModel.isGeneratingSummary ? "Generating..." : (viewModel.summary != nil ? "Regenerate Summary" : "Generate Summary"),
                        systemImage: "text.bubble"
                    )
                }
                .disabled(viewModel.isGeneratingSummary)
                
                if viewModel.summary != nil || ChipSummaryService.shared.getSummary(for: chip) != nil {
                    Button {
                        viewModel.showingSummary.toggle()
                    } label: {
                        Label(viewModel.showingSummary ? "Hide Summary" : "Show Summary", systemImage: viewModel.showingSummary ? "eye.slash" : "eye")
                    }
                }
            }
        }
        .sheet(isPresented: $showingHistory) {
            ChipHistoryView(chip: chip)
        }
        .sheet(isPresented: $viewModel.showingMetadata) {
            if let metadata = viewModel.metadata {
                let urlString = chip.actionData?.url ?? chip.unwrappedTitle.extractURL() ?? ""
                ChipMetadataView(metadata: metadata, url: urlString)
            }
        }
               .onChange(of: viewModel.showingMetadata) { oldValue, newValue in
                   if newValue {
                       let urlString = chip.actionData?.url ?? chip.unwrappedTitle.extractURL() ?? ""
                       AppLogger.info("📄 [ChipRowView] Showing metadata sheet for URL: \(urlString)", category: AppConstants.LoggerCategory.chipRowView)
                       if viewModel.metadata == nil {
                           AppLogger.warning("⚠️ [ChipRowView] Attempted to show metadata sheet but metadata is nil", category: AppConstants.LoggerCategory.chipRowView)
                       }
                   }
               }
               .onAppear {
                   viewModel.updateContext(viewContext)
                   viewModel.onAppear()
               }
               .onChange(of: chip.metadata) { oldValue, newValue in
                   viewModel.onMetadataChanged(oldValue: oldValue, newValue: newValue)
               }
               .onChange(of: chip.title) { oldValue, newValue in
                   print("🔄 [ChipRowView] chip.title changed: '\(oldValue ?? "nil")' -> '\(newValue ?? "nil")'")
                   fflush(stdout)
                   AppLogger.info("🔄 [ChipRowView] chip.title changed: '\(oldValue ?? "nil")' -> '\(newValue ?? "nil")'", category: AppConstants.LoggerCategory.chipRowView)
               }
               .task(id: chip.metadata) {
                   // Check for metadata updates after a delay
                   try? await Task.sleep(nanoseconds: 500_000_000)
                   if let chipImageURL = chip.chipMetadata?.metadataImageURL, viewModel.metadata?.imageURL != chipImageURL {
                       print("🔄 [ChipRowView] Task detected metadata mismatch - reloading")
                       fflush(stdout)
                       viewModel.loadMetadataFromChip()
                   }
               }
        #else
        chipContent
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isActiveTimer ? Color.accentColor.opacity(0.1) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isActiveTimer ? Color.accentColor : Color.clear, lineWidth: 2)
            )
            .swipeActions(edge: .trailing) {
                Button {
                    toggleCompleted()
                } label: {
                    Label(
                        chip.isCompleted ? "Uncomplete" : "Complete",
                        systemImage: chip.isCompleted ? "arrow.uturn.backward" : "checkmark"
                    )
                }
                .tint(chip.isCompleted ? .orange : .green)
            }
            .swipeActions(edge: .leading) {
                Button {
                    showingHistory = true
                } label: {
                    Label("History", systemImage: "clock")
                }
                .tint(.blue)
            }
            .contextMenu {
                Button {
                    executeAction()
                } label: {
                    Label("Open", systemImage: "arrow.up.right")
                }

                Button {
                    showingHistory = true
                } label: {
                    Label("View History", systemImage: "clock")
                }

                Divider()

                Button {
                    toggleCompleted()
                } label: {
                    Label(
                        chip.isCompleted ? "Mark as Active" : "Mark as Complete",
                        systemImage: chip.isCompleted ? "arrow.uturn.backward" : "checkmark"
                    )
                }
            }
            .sheet(isPresented: $showingHistory) {
                ChipHistoryView(chip: chip)
            }
        #endif
    }
    
    @ViewBuilder
    private var chipContent: some View {
        #if os(macOS)
        HStack(spacing: 12) {
            chipInnerContent
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        #else
        Button(action: {
            executeAction()
        }) {
            HStack(spacing: 12) {
                chipInnerContent
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 4)
        }
        .buttonStyle(.plain)
        #endif
    }
    
    
    private var chipInnerContent: some View {
        Group {
            // Thumbnail or Action indicator
            // Check both @Published metadata and chip stored metadata for image URL
            if let thumbnailURL = viewModel.thumbnailURL, let url = URL(string: thumbnailURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        // Show action icon while loading, with reduced opacity if completed
                        ChipViewHelpers.actionIcon(for: chip)
                            .font(.title2)
                            .frame(width: 32, height: 32)
                            .opacity(chip.isCompleted ? 0.5 : 1.0)
                            .onAppear {
                                print("🖼️ [ChipRowView] AsyncImage EMPTY state - loading thumbnail: \(thumbnailURL)")
                                fflush(stdout)
                                AppLogger.debug("🖼️ [ChipRowView] AsyncImage loading thumbnail: \(thumbnailURL)", category: AppConstants.LoggerCategory.chipRowView)
                            }
                            .task {
                                print("🖼️ [ChipRowView] Rendering thumbnail for '\(chip.unwrappedTitle)' with URL: \(thumbnailURL)")
                                fflush(stdout)
                            }
                    case .success(let image):
                        // Show thumbnail with completion overlay if needed
                        ZStack(alignment: .topTrailing) {
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 32, height: 32)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                .opacity(chip.isCompleted ? 0.5 : 1.0)
                            
                            // Completion indicator overlay
                            if chip.isCompleted {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.green)
                                    .background(Circle().fill(.white))
                                    .offset(x: 4, y: -4)
                            }
                        }
                        .onAppear {
                            print("🖼️ [ChipRowView] ✅ AsyncImage SUCCESS - displaying thumbnail: \(thumbnailURL)")
                            fflush(stdout)
                            AppLogger.debug("🖼️ [ChipRowView] ✅ AsyncImage loaded thumbnail successfully: \(thumbnailURL)", category: AppConstants.LoggerCategory.chipRowView)
                        }
                    case .failure(let error):
                        // Fallback to action icon on failure
                        ChipViewHelpers.actionIcon(for: chip)
                            .font(.title2)
                            .frame(width: 32, height: 32)
                            .opacity(chip.isCompleted ? 0.5 : 1.0)
                            .onAppear {
                                print("🖼️ [ChipRowView] ❌ AsyncImage FAILURE - failed to load '\(thumbnailURL)': \(error.localizedDescription)")
                                fflush(stdout)
                                AppLogger.warning("🖼️ [ChipRowView] ❌ AsyncImage failed to load thumbnail '\(thumbnailURL)': \(error.localizedDescription)", category: AppConstants.LoggerCategory.chipRowView)
                            }
                    @unknown default:
                        ChipViewHelpers.actionIcon(for: chip)
                            .font(.title2)
                            .frame(width: 32, height: 32)
                            .opacity(chip.isCompleted ? 0.5 : 1.0)
                            .onAppear {
                                print("🖼️ [ChipRowView] ⚠️ AsyncImage UNKNOWN state")
                                fflush(stdout)
                                AppLogger.debug("🖼️ [ChipRowView] ⚠️ AsyncImage unknown state for thumbnail", category: AppConstants.LoggerCategory.chipRowView)
                            }
                    }
                }
            } else {
                // No thumbnail available - show action icon with completion state
                ChipViewHelpers.actionIcon(for: chip)
                    .font(.title2)
                    .frame(width: 32, height: 32)
                    .opacity(chip.isCompleted ? 0.5 : 1.0)
                    .overlay(alignment: .topTrailing) {
                        if chip.isCompleted {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(.green)
                                .background(Circle().fill(.white))
                                .offset(x: 4, y: -4)
                        }
                    }
                    .onAppear {
                        let stateURL = viewModel.metadata?.imageURL ?? "nil"
                        let chipURL = chip.chipMetadata?.metadataImageURL ?? "nil"
                        let currentThumbnailURL = viewModel.thumbnailURL
                        print("🖼️ [ChipRowView] No thumbnail for '\(chip.unwrappedTitle)' - @Published: \(stateURL), chip.chipMetadata: \(chipURL), thumbnailURL: \(currentThumbnailURL ?? "nil")")
                        fflush(stdout)
                        AppLogger.debug("🖼️ [ChipRowView] No thumbnail URL - @Published: \(stateURL), chip.chipMetadata: \(chipURL)", category: AppConstants.LoggerCategory.chipRowView)
                        if currentThumbnailURL != nil {
                            print("🖼️ [ChipRowView] ⚠️ Thumbnail URL exists but failed to create URL object: \(currentThumbnailURL!)")
                            fflush(stdout)
                            AppLogger.warning("🖼️ [ChipRowView] ⚠️ Thumbnail URL exists but failed to create URL object: \(currentThumbnailURL!)", category: AppConstants.LoggerCategory.chipRowView)
                        }
                    }
            }

            // Content
                    VStack(alignment: .leading, spacing: 4) {
                        // Title with strikethrough if completed
                        // Use metadata title if available (especially for YouTube videos), otherwise use chip title
                        Text(viewModel.displayTitle)
                            .font(.headline)
                            .strikethrough(chip.isCompleted)
                            .foregroundStyle(chip.isCompleted ? .secondary : .primary)
                            .lineLimit(2)
                            .truncationMode(.tail)
                            .onAppear {
                                // Log thumbnail check when title appears
                                let stateURL = viewModel.metadata?.imageURL ?? "nil"
                                let chipURL = chip.chipMetadata?.metadataImageURL ?? "nil"
                                AppLogger.debug("🖼️ [ChipRowView] Thumbnail check for '\(chip.unwrappedTitle)' - @Published imageURL: \(stateURL), chip.chipMetadata.imageURL: \(chipURL)", category: AppConstants.LoggerCategory.chipRowView)
                            }

                // Tags
                if !chip.tags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(chip.tags.prefix(3), id: \.self) { tag in
                            Text("#\(tag)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                // Summary (if available and showing)
                if viewModel.showingSummary, let summary = viewModel.summary ?? ChipSummaryService.shared.getSummary(for: chip) {
                    Text(summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .padding(.top, 4)
                } else if viewModel.isGeneratingSummary {
                    HStack(spacing: 4) {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("Generating summary...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 4)
                }
            }

            Spacer()

            // Timer or interaction count
            if isActiveTimer, let timer = timerManager.activeTimer {
                // Active timer indicator
                HStack(spacing: 4) {
                    Circle()
                        .fill(timer.isRunning ? Color.green : Color.orange)
                        .frame(width: 6, height: 6)
                    Text(timer.formattedElapsed)
                        .font(.system(.caption, design: .monospaced))
                }
                .foregroundStyle(timer.isOvertime ? .red : .primary)
            } else if chip.interactionCount > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "clock")
                    Text("\(chip.interactionCount)x")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Action Icon

    private var actionIcon: some View {
        Group {
            switch chip.actionType {
            case "url":
                // Check if this is a YouTube URL (from actionData, chip metadata, or title)
                let isYouTube = chip.actionData?.preferredApp == "youtube" || 
                               chip.actionData?.url?.contains("youtube.com") == true ||
                               chip.actionData?.url?.contains("youtu.be") == true ||
                               chip.chipMetadata?.metadataSiteName?.lowercased() == "youtube" ||
                               chip.unwrappedTitle.contains("youtube.com") ||
                               chip.unwrappedTitle.contains("youtu.be")
                
                if isYouTube {
                    Image(systemName: "play.rectangle.fill")
                        .foregroundStyle(.red)
                } else {
                    Image(systemName: "link")
                        .foregroundStyle(.blue)
                }
            case "timer":
                Image(systemName: "timer")
                    .foregroundStyle(.orange)
            case "app":
                Image(systemName: "app")
                    .foregroundStyle(.purple)
            default:
                Image(systemName: "square")
                    .foregroundStyle(.gray)
            }
        }
    }

    // MARK: - Actions
    
    
    

    private func executeAction() {
        // Use ActionEngine for centralized action handling
        actionEngine.execute(chip: chip, context: viewContext)
    }

    private func toggleCompleted() {
        ChipViewHelpers.toggleCompleted(
            for: chip,
            in: viewContext,
            timerManager: timerManager,
            isActiveTimer: isActiveTimer
        )
    }
}

// MARK: - Chip Metadata View
struct ChipMetadataView: View {
    let metadata: URLMetadataFetcher.URLMetadata
    let url: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Section("URL") {
                    Text(url)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                }
                
                if let title = metadata.title {
                    Section("Title") {
                        Text(title)
                            .textSelection(.enabled)
                    }
                }
                
                if let description = metadata.description {
                    Section("Description") {
                        Text(description)
                            .textSelection(.enabled)
                    }
                }
                
                if let siteName = metadata.siteName {
                    Section("Site") {
                        Text(siteName)
                            .textSelection(.enabled)
                    }
                }
                
                if let type = metadata.type {
                    Section("Type") {
                        Text(type)
                            .textSelection(.enabled)
                    }
                }
                
                if let imageURL = metadata.imageURL {
                    Section("Thumbnail") {
                        AsyncImage(url: URL(string: imageURL)) { phase in
                            switch phase {
                            case .empty:
                                ProgressView()
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                            case .failure:
                                Image(systemName: "photo")
                                    .foregroundStyle(.secondary)
                            @unknown default:
                                EmptyView()
                            }
                        }
                        .frame(maxHeight: 200)
                        
                        Text(imageURL)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }
            }
            .navigationTitle("URL Metadata")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Chip History View
struct ChipHistoryView: View {
    @ObservedObject var chip: Chip
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent("Total Opens", value: "\(chip.interactionCount)")
                    if let firstInteraction = chip.interactionsArray.last {
                        LabeledContent("First Opened", value: firstInteraction.formattedTimestamp)
                    }
                    if let lastInteraction = chip.interactionsArray.first {
                        LabeledContent("Last Opened", value: lastInteraction.formattedTimestamp)
                    }
                }

                Section("History") {
                    ForEach(chip.interactionsArray) { interaction in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(interaction.unwrappedActionTaken.replacingOccurrences(of: "_", with: " ").capitalized)
                                    .font(.subheadline)
                                if let notes = interaction.notes, !notes.isEmpty {
                                    Text(notes)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Spacer()

                            VStack(alignment: .trailing) {
                                Text(interaction.formattedTimestamp)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if let device = interaction.deviceName {
                                    Text(device)
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(chip.unwrappedTitle)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let chip = Chip(context: context)
    chip.id = UUID()
    chip.title = "30 Min HIIT Workout"
    chip.actionType = "url"
    chip.actionPayload = "{\"url\": \"https://youtube.com/watch?v=xxx\", \"preferredApp\": \"youtube\"}"
    chip.metadata = "{\"tags\": [\"cardio\", \"hiit\"]}"

    return List {
        ChipRowView(chip: chip)
    }
    .environment(\.managedObjectContext, context)
}
