import SwiftUI
import os.log
#if os(macOS)
import AppKit
#endif

struct ChipRowView: View {
    @ObservedObject var chip: Chip
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject private var actionEngine = ActionEngine.shared
    @ObservedObject private var timerManager = TimerManager.shared

    @State private var showingHistory = false
    @State private var isPressed = false

    private var isActiveTimer: Bool {
        timerManager.activeTimer?.chipID == chip.id
    }

    var body: some View {
        #if os(macOS)
        Button(action: {
            let logger = Logger(subsystem: "com.chips.app", category: "ChipRowView")
            print("🖱️ [ChipRowView] Chip button tapped: \(chip.unwrappedTitle)")
            logger.info("🖱️ Chip button tapped: \(chip.unwrappedTitle, privacy: .public)")
            executeAction()
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
            // Action indicator
            actionIcon
                .font(.title2)
                .frame(width: 32)

            // Content
            VStack(alignment: .leading, spacing: 4) {
                // Title with strikethrough if completed
                Text(chip.unwrappedTitle)
                    .font(.headline)
                    .strikethrough(chip.isCompleted)
                    .foregroundStyle(chip.isCompleted ? .secondary : .primary)

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

    // MARK: - Actions

    private func executeAction() {
        // Use ActionEngine for centralized action handling
        actionEngine.execute(chip: chip, context: viewContext)
    }

    private func toggleCompleted() {
        withAnimation {
            chip.isCompleted.toggle()
            chip.completedAt = chip.isCompleted ? Date() : nil

            if chip.isCompleted {
                // Log completion interaction
                let interaction = ChipInteraction(context: viewContext)
                interaction.id = UUID()
                interaction.chip = chip
                interaction.timestamp = Date()
                interaction.actionTaken = "completed"
                interaction.deviceName = ActionEngine.deviceName

                // Stop timer if this chip has active timer
                if isActiveTimer {
                    _ = timerManager.stopTimer()
                }
            }

            try? viewContext.save()
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
