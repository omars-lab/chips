import Foundation
import CoreData

extension ChipInteraction {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<ChipInteraction> {
        return NSFetchRequest<ChipInteraction>(entityName: "ChipInteraction")
    }

    /// Unique identifier
    @NSManaged public var id: UUID?

    /// When the interaction occurred
    @NSManaged public var timestamp: Date?

    /// What action was taken (e.g., "opened_url", "started_timer", "completed")
    @NSManaged public var actionTaken: String?

    /// Duration in seconds (for timer actions)
    @NSManaged public var duration: Int32

    /// User-added notes
    @NSManaged public var notes: String?

    /// Device where interaction occurred
    @NSManaged public var deviceName: String?

    /// Parent chip
    @NSManaged public var chip: Chip?
}

// MARK: - Convenience
extension ChipInteraction {
    var unwrappedActionTaken: String {
        actionTaken ?? "unknown"
    }

    var formattedDuration: String? {
        guard duration > 0 else { return nil }
        let minutes = duration / 60
        let seconds = duration % 60
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        }
        return "\(seconds)s"
    }

    var formattedTimestamp: String {
        guard let timestamp = timestamp else { return "" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }
}

extension ChipInteraction: Identifiable { }
