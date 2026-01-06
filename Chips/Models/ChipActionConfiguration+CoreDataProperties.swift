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
}

