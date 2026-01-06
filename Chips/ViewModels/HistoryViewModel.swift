import Foundation
import SwiftUI
import CoreData
import Combine

/// ViewModel for the History tab
@MainActor
final class HistoryViewModel: ObservableObject {

    @Published var searchText = ""
    @Published var selectedFilter: HistoryFilter = .all
    @Published var isLoading = false

    private var cancellables = Set<AnyCancellable>()

    init() {
        // Set up search debouncing
        $searchText
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    // MARK: - Statistics

    struct Stats {
        let todayCount: Int
        let weekCount: Int
        let streak: Int
        let totalCount: Int
    }

    func calculateStats(from interactions: [ChipInteraction]) -> Stats {
        let calendar = Calendar.current
        let now = Date()

        let todayCount = interactions.filter { interaction in
            guard let timestamp = interaction.timestamp else { return false }
            return calendar.isDateInToday(timestamp)
        }.count

        let weekCount = interactions.filter { interaction in
            guard let timestamp = interaction.timestamp else { return false }
            return calendar.isDate(timestamp, equalTo: now, toGranularity: .weekOfYear)
        }.count

        let streak = calculateStreak(from: interactions)

        return Stats(
            todayCount: todayCount,
            weekCount: weekCount,
            streak: streak,
            totalCount: interactions.count
        )
    }

    private func calculateStreak(from interactions: [ChipInteraction]) -> Int {
        let calendar = Calendar.current
        var streak = 0
        var currentDate = Date()

        // Get unique days with activity
        let daysWithActivity = Set(interactions.compactMap { interaction -> DateComponents? in
            guard let timestamp = interaction.timestamp else { return nil }
            return calendar.dateComponents([.year, .month, .day], from: timestamp)
        })

        while true {
            let components = calendar.dateComponents([.year, .month, .day], from: currentDate)
            if daysWithActivity.contains(components) {
                streak += 1
                guard let previousDay = calendar.date(byAdding: .day, value: -1, to: currentDate) else {
                    break
                }
                currentDate = previousDay
            } else {
                break
            }
        }

        return streak
    }

    // MARK: - Filtering

    func filterInteractions(_ interactions: [ChipInteraction]) -> [ChipInteraction] {
        var result = interactions

        // Apply filter
        switch selectedFilter {
        case .all:
            break
        case .today:
            result = result.filter { interaction in
                guard let timestamp = interaction.timestamp else { return false }
                return Calendar.current.isDateInToday(timestamp)
            }
        case .thisWeek:
            result = result.filter { interaction in
                guard let timestamp = interaction.timestamp else { return false }
                return Calendar.current.isDate(timestamp, equalTo: Date(), toGranularity: .weekOfYear)
            }
        case .completed:
            result = result.filter { $0.actionTaken == "completed" }
        }

        // Apply search
        if !searchText.isEmpty {
            result = result.filter { interaction in
                interaction.chip?.unwrappedTitle.localizedCaseInsensitiveContains(searchText) ?? false
            }
        }

        return result
    }

    // MARK: - Grouping

    func groupByDate(_ interactions: [ChipInteraction]) -> [(String, [ChipInteraction])] {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateStyle = .medium

        let grouped = Dictionary(grouping: interactions) { interaction -> String in
            guard let date = interaction.timestamp else { return "Unknown" }

            if calendar.isDateInToday(date) {
                return "Today"
            } else if calendar.isDateInYesterday(date) {
                return "Yesterday"
            } else {
                return formatter.string(from: date)
            }
        }

        // Sort with Today first, then Yesterday, then by date descending
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

    // MARK: - Export

    func exportToCSV(_ interactions: [ChipInteraction]) -> String {
        var csv = "Timestamp,Chip,Action,Duration,Device,Notes\n"

        let formatter = ISO8601DateFormatter()

        for interaction in interactions {
            let timestamp = interaction.timestamp.map { formatter.string(from: $0) } ?? ""
            let chip = interaction.chip?.unwrappedTitle.replacingOccurrences(of: ",", with: ";") ?? ""
            let action = interaction.unwrappedActionTaken
            let duration = interaction.formattedDuration ?? ""
            let device = interaction.deviceName ?? ""
            let notes = (interaction.notes ?? "").replacingOccurrences(of: ",", with: ";")

            csv += "\(timestamp),\(chip),\(action),\(duration),\(device),\(notes)\n"
        }

        return csv
    }

    func exportToJSON(_ interactions: [ChipInteraction]) -> String? {
        let data = interactions.map { interaction -> [String: Any] in
            var dict: [String: Any] = [
                "id": interaction.id?.uuidString ?? "",
                "action": interaction.unwrappedActionTaken,
                "chip": interaction.chip?.unwrappedTitle ?? "",
                "device": interaction.deviceName ?? ""
            ]

            if let timestamp = interaction.timestamp {
                dict["timestamp"] = ISO8601DateFormatter().string(from: timestamp)
            }

            if interaction.duration > 0 {
                dict["duration"] = interaction.duration
            }

            if let notes = interaction.notes, !notes.isEmpty {
                dict["notes"] = notes
            }

            return dict
        }

        guard let jsonData = try? JSONSerialization.data(withJSONObject: data, options: .prettyPrinted),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return nil
        }

        return jsonString
    }
}

// MARK: - History Filter (moved from HistoryTabView for reusability)

enum HistoryFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case today = "Today"
    case thisWeek = "This Week"
    case completed = "Completed"

    var id: String { rawValue }
}
