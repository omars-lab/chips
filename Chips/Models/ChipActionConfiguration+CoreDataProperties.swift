import Foundation
import CoreData

extension ChipActionConfiguration {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<ChipActionConfiguration> {
        return NSFetchRequest<ChipActionConfiguration>(entityName: "ChipActionConfiguration")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var title: String
    @NSManaged public var summary: String?
    @NSManaged public var configDescription: String?
    @NSManaged public var urlPattern: String?
    @NSManaged public var actionType: String
    @NSManaged public var actionURL: String?
    @NSManaged public var xCallbackScheme: String?
    @NSManaged public var xCallbackPath: String?
    @NSManaged public var xCallbackParams: String?
    @NSManaged public var tags: String?
    @NSManaged public var isEnabled: Bool
    @NSManaged public var priority: Int32
    @NSManaged public var createdAt: Date?
    @NSManaged public var actionsJSON: String?
}

extension ChipActionConfiguration: Identifiable {
    var tagsArray: [String] {
        guard let tags = tags else { return [] }
        return tags.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    var xCallbackParamsDict: [String: String] {
        guard let params = xCallbackParams,
              let data = params.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: String] else {
            return [:]
        }
        return dict
    }

    /// Get the list of actions to execute
    var actions: [ChipActionItem] {
        get {
            guard let json = actionsJSON,
                  let data = json.data(using: .utf8),
                  let items = try? JSONDecoder().decode([ChipActionItem].self, from: data) else {
                // Fallback: convert legacy single action to array
                if xCallbackScheme != nil || actionURL != nil {
                    return [legacyAction].compactMap { $0 }
                }
                return []
            }
            return items
        }
        set {
            if let data = try? JSONEncoder().encode(newValue),
               let json = String(data: data, encoding: .utf8) {
                actionsJSON = json
            }
        }
    }

    /// Convert legacy single action fields to ChipActionItem
    private var legacyAction: ChipActionItem? {
        if actionType == "xcallback", let scheme = xCallbackScheme {
            return ChipActionItem(
                id: UUID(),
                type: .xcallback,
                name: title,
                scheme: scheme,
                path: xCallbackPath,
                params: xCallbackParamsDict,
                template: xCallbackParamsDict["text"]
            )
        } else if let url = actionURL {
            return ChipActionItem(
                id: UUID(),
                type: .openURL,
                name: "Open URL",
                targetURL: url
            )
        }
        return nil
    }
}

// MARK: - ChipActionItem

/// Represents a single action in an action chain
struct ChipActionItem: Codable, Identifiable, Equatable {
    var id: UUID
    var type: ActionType
    var name: String
    var scheme: String?
    var path: String?
    var params: [String: String]?
    var template: String?
    var targetURL: String?
    var delay: Double?  // Delay before executing (seconds)

    enum ActionType: String, Codable, CaseIterable {
        case openURL = "open_url"
        case xcallback = "xcallback"
        case openOriginal = "open_original"
    }

    /// Create from a preset
    static func from(preset: ActionPreset, template: String? = nil) -> ChipActionItem {
        ChipActionItem(
            id: UUID(),
            type: .xcallback,
            name: preset.name,
            scheme: preset.scheme,
            path: preset.path,
            params: preset.defaultParams,
            template: template ?? preset.templateText
        )
    }

    /// "Open Original URL" action
    static var openOriginal: ChipActionItem {
        ChipActionItem(
            id: UUID(),
            type: .openOriginal,
            name: "Open Original URL",
            delay: 0.5  // Small delay to let other actions complete
        )
    }
}

