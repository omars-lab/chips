import Foundation
import CoreData

extension Chip {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Chip> {
        return NSFetchRequest<Chip>(entityName: "Chip")
    }

    /// Unique identifier
    @NSManaged public var id: UUID?

    /// Display title extracted from markdown
    @NSManaged public var title: String?

    /// Original markdown content
    @NSManaged public var rawMarkdown: String?

    /// Section header this chip belongs to
    @NSManaged public var sectionTitle: String?

    /// Action type: "url", "timer", "app", "custom"
    @NSManaged public var actionType: String?

    /// JSON payload with action-specific data
    @NSManaged public var actionPayload: String?

    /// JSON metadata from frontmatter/inline tags
    @NSManaged public var metadata: String?

    /// Sort order within the source
    @NSManaged public var sortOrder: Int32

    /// Whether this chip is marked as complete
    @NSManaged public var isCompleted: Bool

    /// When the chip was marked complete
    @NSManaged public var completedAt: Date?

    /// When the chip was created
    @NSManaged public var createdAt: Date?

    /// Parent source file
    @NSManaged public var source: ChipSource?

    /// Interaction history
    @NSManaged public var interactions: NSSet?
}

// MARK: - Relationship Accessors
extension Chip {
    @objc(addInteractionsObject:)
    @NSManaged public func addToInteractions(_ value: ChipInteraction)

    @objc(removeInteractionsObject:)
    @NSManaged public func removeFromInteractions(_ value: ChipInteraction)

    @objc(addInteractions:)
    @NSManaged public func addToInteractions(_ values: NSSet)

    @objc(removeInteractions:)
    @NSManaged public func removeFromInteractions(_ values: NSSet)
}

// MARK: - Convenience
extension Chip {
    var unwrappedTitle: String {
        title ?? "Untitled"
    }

    var interactionsArray: [ChipInteraction] {
        let set = interactions as? Set<ChipInteraction> ?? []
        return set.sorted { ($0.timestamp ?? .distantPast) > ($1.timestamp ?? .distantPast) }
    }

    var interactionCount: Int {
        interactions?.count ?? 0
    }

    /// Decoded action payload (getter and setter)
    var actionData: ActionPayload? {
        get {
            guard let payload = actionPayload,
                  let data = payload.data(using: .utf8) else { return nil }
            return try? JSONDecoder().decode(ActionPayload.self, from: data)
        }
        set {
            if let newValue = newValue,
               let encoded = try? JSONEncoder().encode(newValue),
               let jsonString = String(data: encoded, encoding: .utf8) {
                actionPayload = jsonString
            } else {
                actionPayload = nil
            }
        }
    }

    /// Decoded metadata (getter and setter)
    var chipMetadata: ChipMetadata? {
        get {
            guard let meta = metadata,
                  let data = meta.data(using: .utf8) else { return nil }
            return try? JSONDecoder().decode(ChipMetadata.self, from: data)
        }
        set {
            if let newValue = newValue,
               let encoded = try? JSONEncoder().encode(newValue),
               let jsonString = String(data: encoded, encoding: .utf8) {
                metadata = jsonString
            } else {
                metadata = nil
            }
        }
    }

    /// Tags extracted from metadata
    var tags: [String] {
        chipMetadata?.tags ?? []
    }
}

extension Chip: Identifiable { }

// MARK: - Supporting Types

public struct ActionPayload: Codable {
    public var url: String?
    public var preferredApp: String?
    public var expectedDuration: Int? // seconds
    
    public init(url: String? = nil, preferredApp: String? = nil, expectedDuration: Int? = nil) {
        self.url = url
        self.preferredApp = preferredApp
        self.expectedDuration = expectedDuration
    }
}

struct ChipMetadata: Codable {
    var tags: [String]?
    var duration: String? // e.g., "30m"
    var repeatCount: Int?
    var metadataTitle: String? // Title from URL metadata (e.g., YouTube video title)
    var metadataDescription: String? // Description from URL metadata
    var metadataImageURL: String? // Image URL from URL metadata
    var metadataSiteName: String? // Site name from URL metadata
    var metadataType: String? // Type from URL metadata
    var summary: String? // Generated summary
    var summaryGeneratedAt: String? // ISO8601 timestamp
}
