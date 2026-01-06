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

    @State private var isHovered = false
    @State private var showingHistory = false

    private var isActiveTimer: Bool {
        timerManager.activeTimer?.chipID == chip.id
    }

    var body: some View {
        Button {
            actionEngine.execute(chip: chip, context: viewContext)
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                // Header with icon and title
                HStack(spacing: 12) {
                    actionIcon
                        .font(.title2)
                        .frame(width: 40, height: 40)
                        .background(iconBackgroundColor.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(chip.unwrappedTitle)
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
                        Label(formatDuration(TimeInterval(duration)), systemImage: "timer")
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
    }

    // MARK: - Action Icon

    private var actionIcon: some View {
        Group {
            switch chip.actionType {
            case "url":
                if chip.actionData?.preferredApp == "youtube" {
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

    private var iconBackgroundColor: Color {
        switch chip.actionType {
        case "url":
            return chip.actionData?.preferredApp == "youtube" ? .red : .blue
        case "timer":
            return .orange
        case "app":
            return .purple
        default:
            return .gray
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

    // MARK: - Actions

    private func toggleCompleted() {
        withAnimation {
            chip.isCompleted.toggle()
            chip.completedAt = chip.isCompleted ? Date() : nil

            if chip.isCompleted {
                let interaction = ChipInteraction(context: viewContext)
                interaction.id = UUID()
                interaction.chip = chip
                interaction.timestamp = Date()
                interaction.actionTaken = "completed"
                interaction.deviceName = ActionEngine.deviceName

                if isActiveTimer {
                    _ = timerManager.stopTimer()
                }
            }

            try? viewContext.save()
        }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        if minutes >= 60 {
            let hours = minutes / 60
            let mins = minutes % 60
            return "\(hours)h\(mins > 0 ? " \(mins)m" : "")"
        }
        return "\(minutes)m"
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
