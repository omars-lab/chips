import Foundation
import CoreData

/// Manages chip action configurations
@MainActor
final class ChipActionConfigurationManager: ObservableObject {
    static let shared = ChipActionConfigurationManager()
    
    private init() {}
    
    /// Find matching configuration for a chip
    func findConfiguration(for chip: Chip, context: NSManagedObjectContext) -> ChipActionConfiguration? {
        let fetchRequest = ChipActionConfiguration.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "isEnabled == YES")
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \ChipActionConfiguration.priority, ascending: false)]
        
        guard let configs = try? context.fetch(fetchRequest) else { return nil }
        
        // Get chip URL if available
        guard let chipURL = chip.actionData?.url else { return nil }
        
        // Find first matching configuration
        for config in configs {
            if matches(config: config, chipURL: chipURL, chip: chip) {
                return config
            }
        }
        
        return nil
    }
    
    private func matches(config: ChipActionConfiguration, chipURL: String, chip: Chip) -> Bool {
        // Match by URL pattern
        if let pattern = config.urlPattern, !pattern.isEmpty {
            if matchesPattern(pattern: pattern, url: chipURL) {
                return true
            }
        }
        
        // Match by tags
        if let configTags = config.tags, !configTags.isEmpty {
            let chipTags = chip.tags
            let configTagsArray = configTags.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            let chipTagsLower = chipTags.map { $0.lowercased() }
            
            if configTagsArray.contains(where: { chipTagsLower.contains($0) }) {
                return true
            }
        }
        
        return false
    }
    
    private func matchesPattern(pattern: String, url: String) -> Bool {
        // Simple pattern matching - supports wildcards
        let patternLower = pattern.lowercased()
        let urlLower = url.lowercased()
        
        // Exact match
        if patternLower == urlLower {
            return true
        }
        
        // Contains match
        if urlLower.contains(patternLower) {
            return true
        }
        
        // Wildcard matching (simple)
        if patternLower.contains("*") {
            let regexPattern = patternLower
                .replacingOccurrences(of: "*", with: ".*")
                .replacingOccurrences(of: ".", with: "\\.")
            if let regex = try? NSRegularExpression(pattern: regexPattern, options: .caseInsensitive) {
                let range = NSRange(location: 0, length: urlLower.utf16.count)
                return regex.firstMatch(in: urlLower, options: [], range: range) != nil
            }
        }
        
        return false
    }
    
    /// Build action URL from configuration
    func buildActionURL(from config: ChipActionConfiguration, chip: Chip) -> URL? {
        switch config.actionType {
        case "url":
            if let actionURL = config.actionURL {
                return URL(string: actionURL)
            }
            // Fallback to chip's URL
            return chip.actionData?.url.flatMap { URL(string: $0) }
            
        case "xcallback":
            return buildXCallbackURL(from: config, chip: chip)
            
        default:
            return chip.actionData?.url.flatMap { URL(string: $0) }
        }
    }
    
    private func buildXCallbackURL(from config: ChipActionConfiguration, chip: Chip) -> URL? {
        guard let scheme = config.xCallbackScheme else { return nil }
        
        var components = URLComponents()
        components.scheme = scheme
        components.host = "x-callback-url"
        
        if let path = config.xCallbackPath {
            components.path = "/\(path)"
        }
        
        var queryItems: [URLQueryItem] = []
        
        // Add configured params
        let params = config.xCallbackParamsDict
        for (key, value) in params {
            // Replace placeholders with chip data
            let resolvedValue = resolvePlaceholders(in: value, chip: chip)
            queryItems.append(URLQueryItem(name: key, value: resolvedValue))
        }
        
        // Add common placeholders if not already present
        if !params.keys.contains("title") {
            queryItems.append(URLQueryItem(name: "title", value: chip.unwrappedTitle))
        }
        if !params.keys.contains("url") {
            queryItems.append(URLQueryItem(name: "url", value: chip.actionData?.url ?? ""))
        }
        
        components.queryItems = queryItems.isEmpty ? nil : queryItems
        
        return components.url
    }
    
    private func resolvePlaceholders(in template: String, chip: Chip) -> String {
        var result = template
        result = result.replacingOccurrences(of: "{{title}}", with: chip.unwrappedTitle)
        result = result.replacingOccurrences(of: "{{url}}", with: chip.actionData?.url ?? "")
        result = result.replacingOccurrences(of: "{{tags}}", with: chip.tags.joined(separator: ","))
        return result
    }
}

