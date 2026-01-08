import SwiftUI

/// Grid layout for chips on iPad and Mac
struct ChipGridView: View {
    let chips: [Chip]
    let sectionTitle: String?

    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject private var timerManager = TimerManager.shared

    private let columns = [
        GridItem(.adaptive(minimum: 280, maximum: 400), spacing: 16)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(chips) { chip in
                ChipCardView(chip: chip)
            }
        }
        .padding()
    }
}

/// Card-style chip view for grid layout
struct ChipCardView: View {
    @ObservedObject var chip: Chip
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject private var actionEngine = ActionEngine.shared
    @ObservedObject private var timerManager = TimerManager.shared

    // Use shared ViewModel for metadata and summary logic
    @StateObject private var viewModel: ChipViewModel

    @State private var isHovered = false
    @State private var showingHistory = false

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
        Button {
            actionEngine.execute(chip: chip, context: viewContext)
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                // Header with thumbnail/icon and title
                HStack(spacing: 12) {
                    // Thumbnail or Action indicator
                    if let thumbnailURL = viewModel.thumbnailURL, let url = URL(string: thumbnailURL) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .empty:
                                ChipViewHelpers.actionIcon(for: chip)
                                    .font(.title2)
                                    .frame(width: 40, height: 40)
                                    .background(ChipViewHelpers.iconBackgroundColor(for: chip).opacity(0.15))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .onAppear {
                                        print("🖼️ [ChipCardView] AsyncImage EMPTY - loading thumbnail: \(thumbnailURL)")
                                        fflush(stdout)
                                    }
                            case .success(let image):
                                ZStack(alignment: .topTrailing) {
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 40, height: 40)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                        .opacity(chip.isCompleted ? 0.5 : 1.0)
                                    
                                    if chip.isCompleted {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 12))
                                            .foregroundStyle(.green)
                                            .background(Circle().fill(.white))
                                            .offset(x: 4, y: -4)
                                    }
                                }
                                .onAppear {
                                    print("🖼️ [ChipCardView] ✅ AsyncImage SUCCESS - displaying thumbnail: \(thumbnailURL)")
                                    fflush(stdout)
                                }
                            case .failure(let error):
                                ChipViewHelpers.actionIcon(for: chip)
                                    .font(.title2)
                                    .frame(width: 40, height: 40)
                                    .background(ChipViewHelpers.iconBackgroundColor(for: chip).opacity(0.15))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .onAppear {
                                        print("🖼️ [ChipCardView] ❌ AsyncImage FAILURE - failed to load '\(thumbnailURL)': \(error.localizedDescription)")
                                        fflush(stdout)
                                    }
                            @unknown default:
                                ChipViewHelpers.actionIcon(for: chip)
                                    .font(.title2)
                                    .frame(width: 40, height: 40)
                                    .background(ChipViewHelpers.iconBackgroundColor(for: chip).opacity(0.15))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    } else {
                        // No thumbnail - show action icon with completion overlay
                        ChipViewHelpers.actionIcon(for: chip)
                            .font(.title2)
                            .frame(width: 40, height: 40)
                            .background(ChipViewHelpers.iconBackgroundColor(for: chip).opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
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
                                print("🖼️ [ChipCardView] No thumbnail URL - @Published: \(stateURL), chip.chipMetadata: \(chipURL)")
                                fflush(stdout)
                            }
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(viewModel.displayTitle)
                            .font(.headline)
                            .strikethrough(chip.isCompleted)
                            .foregroundStyle(chip.isCompleted ? .secondary : .primary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)

                        if let url = chip.actionData?.url {
                            Text(URL(string: url)?.host ?? url)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }

                    Spacer()
                }

                // Tags
                if !chip.tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(chip.tags, id: \.self) { tag in
                                Text("#\(tag)")
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.secondary.opacity(0.1))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
                
                // Summary (if available and showing)
                if viewModel.showingSummary, let summary = viewModel.summary ?? ChipSummaryService.shared.getSummary(for: chip) {
                    Text(summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
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

                // Footer with stats and timer
                HStack {
                    // Interaction count
                    if chip.interactionCount > 0 {
                        Label("\(chip.interactionCount)", systemImage: "clock")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    // Duration tag if present
                    if let duration = chip.actionData?.expectedDuration {
                        Label(ChipViewHelpers.formatDuration(TimeInterval(duration)), systemImage: "timer")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    // Active timer indicator
                    if isActiveTimer, let timer = timerManager.activeTimer {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(timer.isRunning ? Color.green : Color.orange)
                                .frame(width: 8, height: 8)
                            Text(timer.formattedElapsed)
                                .font(.system(.caption, design: .monospaced))
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.15))
                        .clipShape(Capsule())
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(borderColor, lineWidth: isActiveTimer ? 2 : (isHovered ? 1 : 0))
            )
            .shadow(color: .black.opacity(isHovered ? 0.1 : 0.05), radius: isHovered ? 8 : 4, y: 2)
        }
        #if os(macOS)
        .buttonStyle(.borderless)
        #else
        .buttonStyle(.plain)
        #endif
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .contextMenu {
            Button {
                actionEngine.execute(chip: chip, context: viewContext)
            } label: {
                Label("Open", systemImage: "arrow.up.right")
            }

            if chip.hasTimerTag || chip.actionData?.expectedDuration != nil {
                Button {
                    timerManager.startTimer(
                        chipID: chip.id ?? UUID(),
                        chipTitle: chip.unwrappedTitle,
                        expectedDuration: chip.actionData?.expectedDuration.map { TimeInterval($0) }
                    )
                } label: {
                    Label("Start Timer", systemImage: "timer")
                }
            }

            Divider()

            Button {
                showingHistory = true
            } label: {
                Label("View History", systemImage: "clock")
            }

            Divider()

            Button {
                ChipViewHelpers.toggleCompleted(
                    for: chip,
                    in: viewContext,
                    timerManager: timerManager,
                    isActiveTimer: isActiveTimer
                )
            } label: {
                Label(
                    chip.isCompleted ? "Mark as Active" : "Mark as Complete",
                    systemImage: chip.isCompleted ? "arrow.uturn.backward" : "checkmark"
                )
            }
            
            // Show metadata and summary options if chip has a URL
            if viewModel.hasURL {
                Divider()
                
                Button {
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
        .onAppear {
            viewModel.updateContext(viewContext)
            viewModel.onAppear()
        }
        .onChange(of: chip.metadata) { oldValue, newValue in
            viewModel.onMetadataChanged(oldValue: oldValue, newValue: newValue)
        }
        .task(id: chip.metadata) {
            // Check for metadata updates after a delay
            try? await Task.sleep(nanoseconds: 500_000_000)
            if let chipImageURL = chip.chipMetadata?.metadataImageURL, viewModel.metadata?.imageURL != chipImageURL {
                print("🔄 [ChipCardView] Task detected metadata mismatch - reloading")
                fflush(stdout)
                viewModel.loadMetadataFromChip()
            }
        }
    }
    

    private var cardBackground: Color {
        #if os(macOS)
        return Color(nsColor: .controlBackgroundColor)
        #else
        return Color(uiColor: .secondarySystemGroupedBackground)
        #endif
    }

    private var borderColor: Color {
        if isActiveTimer {
            return .accentColor
        }
        return .secondary.opacity(0.2)
    }

}

// MARK: - Preview

#Preview {
    let context = PersistenceController.preview.container.viewContext

    let chip1 = Chip(context: context)
    chip1.id = UUID()
    chip1.title = "30 Min HIIT Workout"
    chip1.actionType = "url"
    chip1.actionPayload = "{\"url\": \"https://youtube.com/watch?v=xxx\", \"preferredApp\": \"youtube\", \"duration\": 1800}"
    chip1.metadata = "{\"tags\": [\"cardio\", \"hiit\"]}"

    let chip2 = Chip(context: context)
    chip2.id = UUID()
    chip2.title = "Walking Workout - Low Impact"
    chip2.actionType = "url"
    chip2.actionPayload = "{\"url\": \"https://youtube.com/watch?v=yyy\"}"
    chip2.metadata = "{\"tags\": [\"walking\", \"beginner\"]}"

    return ChipGridView(chips: [chip1, chip2], sectionTitle: "Cardio")
        .environment(\.managedObjectContext, context)
        .frame(width: 800, height: 400)
}
