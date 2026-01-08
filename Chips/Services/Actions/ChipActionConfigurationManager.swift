import Foundation
import CoreData

/// Manages chip action configurations and builds action URLs
@MainActor
final class ChipActionConfigurationManager: ObservableObject {
    static let shared = ChipActionConfigurationManager()

    private init() {}
    
    // MARK: - URL Extraction
    
    /// Extract URL from chip, checking actionData first, then falling back to title
    private func extractURL(from chip: Chip) -> String? {
        // First try actionData
        if let urlFromActionData = chip.actionData?.url {
            return urlFromActionData
        }
        
        // Fallback: check if title itself is a URL
        if let url = chip.unwrappedTitle.extractURL() {
            AppLogger.info("🔗 [ChipActionConfigurationManager] Extracted URL from title: \(url)", category: AppConstants.LoggerCategory.actionEngine)
            return url
        }
        
        return nil
    }

    /// Find matching configuration for a chip
    func findConfiguration(for chip: Chip, context: NSManagedObjectContext) -> ChipActionConfiguration? {
        AppLogger.info("🔍 [ChipActionConfigurationManager] Finding configuration for chip: \(chip.unwrappedTitle)", category: AppConstants.LoggerCategory.actionEngine)
        
        let fetchRequest = ChipActionConfiguration.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "isEnabled == YES")
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \ChipActionConfiguration.priority, ascending: false)]

        guard let configs = try? context.fetch(fetchRequest) else {
            AppLogger.warning("⚠️ [ChipActionConfigurationManager] Failed to fetch configurations", category: AppConstants.LoggerCategory.actionEngine)
            return nil
        }
        
        AppLogger.info("📋 [ChipActionConfigurationManager] Found \(configs.count) enabled configuration(s)", category: AppConstants.LoggerCategory.actionEngine)

        // Get chip URL if available
        guard let chipURL = extractURL(from: chip) else {
            AppLogger.warning("⚠️ [ChipActionConfigurationManager] Chip has no URL in actionData or title", category: AppConstants.LoggerCategory.actionEngine)
            return nil
        }
        
        AppLogger.info("🔗 [ChipActionConfigurationManager] Chip URL: \(chipURL)", category: AppConstants.LoggerCategory.actionEngine)

        // Find first matching configuration
        for config in configs {
            let title = config.title
            
            if matches(config: config, chipURL: chipURL, chip: chip) {
                AppLogger.info("✅ [ChipActionConfigurationManager] Match found: \(title)", category: AppConstants.LoggerCategory.actionEngine)
                return config
            } else {
                AppLogger.info("❌ [ChipActionConfigurationManager] No match for: \(title)", category: AppConstants.LoggerCategory.actionEngine)
            }
        }
        
        AppLogger.info("⚠️ [ChipActionConfigurationManager] No matching configuration found", category: AppConstants.LoggerCategory.actionEngine)

        return nil
    }

    private func matches(config: ChipActionConfiguration, chipURL: String, chip: Chip) -> Bool {
        // Match by URL pattern
        if let pattern = config.urlPattern, !pattern.isEmpty {
            if matchesPattern(pattern: pattern, url: chipURL) {
                AppLogger.info("✅ [ChipActionConfigurationManager] URL pattern matched!", category: AppConstants.LoggerCategory.actionEngine)
                return true
            }
        }

        // Match by tags
        if let configTags = config.tags, !configTags.isEmpty {
            let chipTags = chip.tags
            let configTagsArray = configTags.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            let chipTagsLower = chipTags.map { $0.lowercased() }

            if configTagsArray.contains(where: { chipTagsLower.contains($0) }) {
                AppLogger.info("✅ [ChipActionConfigurationManager] Tag matched!", category: AppConstants.LoggerCategory.actionEngine)
                return true
            }
        }

        return false
    }

    private func matchesPattern(pattern: String, url: String) -> Bool {
        let patternLower = pattern.lowercased()
        let urlLower = url.lowercased()

        // Exact match
        if patternLower == urlLower {
            return true
        }

        // Contains match (most common use case)
        if urlLower.contains(patternLower) {
            return true
        }
        
        // Domain matching: Extract host from URL and check domain variations
        if let urlObj = URL(string: url), let urlHost = urlObj.host {
            let urlHostLower = urlHost.lowercased()
            
            // Check if pattern matches the host directly
            if urlHostLower == patternLower || urlHostLower.contains(patternLower) {
                return true
            }
            
            // Check domain variations for common services
            if matchesDomainVariation(pattern: patternLower, urlHost: urlHostLower) {
                return true
            }
        }

        // Wildcard matching
        if patternLower.contains("*") {
            let regexPattern = NSRegularExpression.escapedPattern(for: patternLower)
                .replacingOccurrences(of: "\\*", with: ".*")
            if let regex = try? NSRegularExpression(pattern: regexPattern, options: .caseInsensitive) {
                let range = NSRange(location: 0, length: urlLower.utf16.count)
                return regex.firstMatch(in: urlLower, options: [], range: range) != nil
            }
        }

        return false
    }
    
    /// Check if pattern matches common domain variations
    private func matchesDomainVariation(pattern: String, urlHost: String) -> Bool {
        // YouTube variations
        if (pattern == "youtube.com" || pattern.contains("youtube.com")) && 
           (urlHost == "youtu.be" || urlHost.contains("youtu.be")) {
            return true
        }
        if (pattern == "youtu.be" || pattern.contains("youtu.be")) && 
           (urlHost == "youtube.com" || urlHost.contains("youtube.com")) {
            return true
        }
        
        // Twitter/X variations
        if (pattern == "twitter.com" || pattern.contains("twitter.com")) && 
           (urlHost == "x.com" || urlHost.contains("x.com")) {
            return true
        }
        if (pattern == "x.com" || pattern.contains("x.com")) && 
           (urlHost == "twitter.com" || urlHost.contains("twitter.com")) {
            return true
        }
        
        return false
    }

    // MARK: - Build Action URLs

    /// Build all action URLs from configuration
    func buildActionURLs(from config: ChipActionConfiguration, chip: Chip) -> [(action: ChipActionItem, url: URL?)] {
        let actions = config.actions
        let chipURL = extractURL(from: chip) ?? ""
        let extracted = URLVariableExtractor.extract(from: chipURL, chipTitle: chip.unwrappedTitle)

        return actions.map { action in
            let url = buildURL(for: action, variables: extracted.variables, originalURL: chipURL)
            return (action, url)
        }
    }

    /// Build URL for a single action item
    func buildURL(for action: ChipActionItem, variables: [String: String], originalURL: String) -> URL? {
        switch action.type {
        case .openOriginal:
            return URL(string: originalURL)

        case .openURL:
            if let targetURL = action.targetURL {
                let resolved = URLVariableExtractor.resolve(template: targetURL, with: variables)
                return URL(string: resolved)
            }
            return URL(string: originalURL)

        case .xcallback:
            return buildXCallbackURL(for: action, variables: variables)
        }
    }

    private func buildXCallbackURL(for action: ChipActionItem, variables: [String: String]) -> URL? {
        guard let scheme = action.scheme else { return nil }

        var components = URLComponents()
        components.scheme = scheme
        components.host = "x-callback-url"

        if let path = action.path, !path.isEmpty {
            components.path = "/\(path)"
        }

        var queryItems: [URLQueryItem] = []

        // Add params from action
        if let params = action.params {
            for (key, value) in params {
                let resolvedValue = URLVariableExtractor.resolve(template: value, with: variables)
                queryItems.append(URLQueryItem(name: key, value: resolvedValue))
            }
        }

        // Add template as text param if present and not already in params
        if let template = action.template, action.params?["text"] == nil {
            let resolvedText = URLVariableExtractor.resolve(template: template, with: variables)
            queryItems.append(URLQueryItem(name: "text", value: resolvedText))
        }

        components.queryItems = queryItems.isEmpty ? nil : queryItems

        return components.url
    }

    // MARK: - Legacy Support

    /// Build single action URL (legacy)
    func buildActionURL(from config: ChipActionConfiguration, chip: Chip) -> URL? {
        let actions = buildActionURLs(from: config, chip: chip)
        return actions.first?.url
    }

    /// Preview what the action URL would look like
    func previewActionURL(config: ChipActionConfiguration, sampleURL: String, sampleTitle: String) -> String {
        let extracted = URLVariableExtractor.extract(from: sampleURL, chipTitle: sampleTitle)

        guard let scheme = config.xCallbackScheme else { return "Invalid configuration" }

        var components = URLComponents()
        components.scheme = scheme
        components.host = "x-callback-url"

        if let path = config.xCallbackPath, !path.isEmpty {
            components.path = "/\(path)"
        }

        var queryItems: [URLQueryItem] = []
        let params = config.xCallbackParamsDict

        for (key, value) in params {
            let resolvedValue = URLVariableExtractor.resolve(template: value, with: extracted.variables)
            queryItems.append(URLQueryItem(name: key, value: resolvedValue))
        }

        components.queryItems = queryItems.isEmpty ? nil : queryItems

        return components.url?.absoluteString ?? "Failed to build URL"
    }
}
