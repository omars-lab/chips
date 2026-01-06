import Foundation
import CoreData

extension ChipSource {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<ChipSource> {
        return NSFetchRequest<ChipSource>(entityName: "ChipSource")
    }

    /// Unique identifier
    @NSManaged public var id: UUID?

    /// Display name (derived from file name)
    @NSManaged public var name: String?

    /// Path to the markdown file in iCloud Drive
    @NSManaged public var iCloudPath: String?

    /// When the file was last parsed
    @NSManaged public var lastParsed: Date?

    /// File content checksum for change detection
    @NSManaged public var checksum: String?

    /// Chips parsed from this source
    @NSManaged public var chips: NSSet?
}

// MARK: - Relationship Accessors
extension ChipSource {
    @objc(addChipsObject:)
    @NSManaged public func addToChips(_ value: Chip)

    @objc(removeChipsObject:)
    @NSManaged public func removeFromChips(_ value: Chip)

    @objc(addChips:)
    @NSManaged public func addToChips(_ values: NSSet)

    @objc(removeChips:)
    @NSManaged public func removeFromChips(_ values: NSSet)
}

// MARK: - Convenience
extension ChipSource {
    var chipsArray: [Chip] {
        let set = chips as? Set<Chip> ?? []
        return set.sorted { ($0.sortOrder) < ($1.sortOrder) }
    }

    var unwrappedName: String {
        name ?? "Untitled"
    }

    var unwrappedPath: String {
        iCloudPath ?? ""
    }
}

extension ChipSource: Identifiable { }
