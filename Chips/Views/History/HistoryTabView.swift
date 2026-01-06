import SwiftUI
import CoreData

struct HistoryTabView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \ChipInteraction.timestamp, ascending: false)],
        animation: .default
    )
    private var interactions: FetchedResults<ChipInteraction>

    @State private var searchText = ""
    @State private var selectedFilter: HistoryFilter = .all

    var filteredInteractions: [ChipInteraction] {
        var result = Array(interactions)

        // Apply filter
        switch selectedFilter {
        case .all:
            break
        case .today:
            result = result.filter {
                guard let timestamp = $0.timestamp else { return false }
                return Calendar.current.isDateInToday(timestamp)
            }
        case .thisWeek:
            result = result.filter {
                guard let timestamp = $0.timestamp else { return false }
                return Calendar.current.isDate(timestamp, equalTo: Date(), toGranularity: .weekOfYear)
            }
        case .completed:
            result = result.filter { $0.actionTaken == "completed" }
        }

        // Apply search
        if !searchText.isEmpty {
            result = result.filter {
                $0.chip?.unwrappedTitle.localizedCaseInsensitiveContains(searchText) ?? false
            }
        }

        return result
    }

    var groupedByDate: [(String, [ChipInteraction])] {
        let grouped = Dictionary(grouping: filteredInteractions) { interaction -> String in
            guard let date = interaction.timestamp else { return "Unknown" }
            if Calendar.current.isDateInToday(date) {
                return "Today"
            } else if Calendar.current.isDateInYesterday(date) {
                return "Yesterday"
            } else {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                return formatter.string(from: date)
            }
        }

        let order = ["Today", "Yesterday"]
        return grouped.sorted { first, second in
            if let firstIdx = order.firstIndex(of: first.key),
               let secondIdx = order.firstIndex(of: second.key) {
                return firstIdx < secondIdx
            } else if order.contains(first.key) {
                return true
            } else if order.contains(second.key) {
                return false
            } else {
                return first.key > second.key
            }
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if interactions.isEmpty {
                    ContentUnavailableView(
                        "No History",
                        systemImage: "clock",
                        description: Text("Your chip interactions will appear here.")
                    )
                } else if filteredInteractions.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    List {
                        // Stats Section
                        Section {
                            StatsCardsView(interactions: Array(interactions))
                        }

                        // Timeline
                        ForEach(groupedByDate, id: \.0) { date, dateInteractions in
                            Section(date) {
                                ForEach(dateInteractions) { interaction in
                                    InteractionRowView(interaction: interaction)
                                }
                            }
                        }
                    }
                    #if os(iOS)
                    .listStyle(.insetGrouped)
                    #else
                    .listStyle(.sidebar)
                    #endif
                }
            }
            .navigationTitle("History")
            .searchable(text: $searchText, prompt: "Search history")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Picker("Filter", selection: $selectedFilter) {
                            ForEach(HistoryFilter.allCases) { filter in
                                Text(filter.rawValue).tag(filter)
                            }
                        }
                    } label: {
                        Label("Filter", systemImage: selectedFilter == .all ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                    }
                }
            }
        }
    }
}

// MARK: - Stats Cards
struct StatsCardsView: View {
    let interactions: [ChipInteraction]

    var todayCount: Int {
        interactions.filter {
            guard let timestamp = $0.timestamp else { return false }
            return Calendar.current.isDateInToday(timestamp)
        }.count
    }

    var weekCount: Int {
        interactions.filter {
            guard let timestamp = $0.timestamp else { return false }
            return Calendar.current.isDate(timestamp, equalTo: Date(), toGranularity: .weekOfYear)
        }.count
    }

    var streak: Int {
        // Calculate consecutive days with activity
        var streak = 0
        var currentDate = Date()

        while true {
            let hasActivity = interactions.contains {
                guard let timestamp = $0.timestamp else { return false }
                return Calendar.current.isDate(timestamp, inSameDayAs: currentDate)
            }

            if hasActivity {
                streak += 1
                currentDate = Calendar.current.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
            } else {
                break
            }
        }

        return streak
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                StatCard(title: "Today", value: "\(todayCount)", icon: "sun.max.fill", color: .orange)
                StatCard(title: "This Week", value: "\(weekCount)", icon: "calendar", color: .blue)
                StatCard(title: "Streak", value: "\(streak) days", icon: "flame.fill", color: .red)
                StatCard(title: "Total", value: "\(interactions.count)", icon: "chart.bar.fill", color: .green)
            }
            .padding(.horizontal, 4)
        }
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(value)
                .font(.title2)
                .fontWeight(.semibold)
        }
        .frame(minWidth: 100, alignment: .leading)
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Interaction Row
struct InteractionRowView: View {
    @ObservedObject var interaction: ChipInteraction

    var body: some View {
        HStack(spacing: 12) {
            // Action icon
            Image(systemName: iconForAction(interaction.actionTaken))
                .font(.title3)
                .foregroundStyle(colorForAction(interaction.actionTaken))
                .frame(width: 28)

            // Details
            VStack(alignment: .leading, spacing: 2) {
                Text(interaction.chip?.unwrappedTitle ?? "Unknown Chip")
                    .font(.subheadline)
                    .fontWeight(.medium)

                HStack(spacing: 8) {
                    Text(interaction.unwrappedActionTaken.replacingOccurrences(of: "_", with: " ").capitalized)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let duration = interaction.formattedDuration {
                        Text("• \(duration)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            // Time
            VStack(alignment: .trailing, spacing: 2) {
                if let timestamp = interaction.timestamp {
                    Text(timestamp, style: .time)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let device = interaction.deviceName {
                    Text(device)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private func iconForAction(_ action: String?) -> String {
        switch action {
        case "opened_url": return "arrow.up.right"
        case "started_timer": return "timer"
        case "stopped_timer": return "stop.fill"
        case "completed": return "checkmark.circle.fill"
        default: return "circle"
        }
    }

    private func colorForAction(_ action: String?) -> Color {
        switch action {
        case "opened_url": return .blue
        case "started_timer": return .orange
        case "stopped_timer": return .orange
        case "completed": return .green
        default: return .gray
        }
    }
}

#Preview {
    HistoryTabView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
