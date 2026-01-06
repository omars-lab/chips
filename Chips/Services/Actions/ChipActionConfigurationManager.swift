import Foundation
import CoreData
import os.log

/// Manages chip action configurations and builds action URLs
@MainActor
final class ChipActionConfigurationManager: ObservableObject {
    static let shared = ChipActionConfigurationManager()
    
    private let logger = Logger(subsystem: "com.chips.app", category: "ChipActionConfigurationManager")

    private init() {}
    
    // MARK: - URL Extraction
    
    /// Extract URL from chip, checking actionData first, then falling back to title
    private func extractURL(from chip: Chip) -> String? {
        // First try actionData
        if let urlFromActionData = chip.actionData?.url {
            return urlFromActionData
        }
        
        // Fallback: check if title itself is a URL
        let title = chip.unwrappedTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = URL(string: title), url.scheme != nil {
            logger.info("🔗 [ChipActionConfigurationManager] Extracted URL from title: \(title, privacy: .public)")
            print("🔗 [ChipActionConfigurationManager] Extracted URL from title: \(title)")
            return title
        }
        
        return nil
    }

    /// Find matching configuration for a chip
    func findConfiguration(for chip: Chip, context: NSManagedObjectContext) -> ChipActionConfiguration? {
        logger.info("🔍 [ChipActionConfigurationManager] Finding configuration for chip: \(chip.unwrappedTitle, privacy: .public)")
        print("🔍 [ChipActionConfigurationManager] Finding configuration for chip: \(chip.unwrappedTitle)")
        
        let fetchRequest = ChipActionConfiguration.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "isEnabled == YES")
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \ChipActionConfiguration.priority, ascending: false)]

        guard let configs = try? context.fetch(fetchRequest) else {
            logger.warning("⚠️ [ChipActionConfigurationManager] Failed to fetch configurations")
            print("⚠️ [ChipActionConfigurationManager] Failed to fetch configurations")
            return nil
        }
        
        logger.info("📋 [ChipActionConfigurationManager] Found \(configs.count) enabled configuration(s)")
        print("📋 [ChipActionConfigurationManager] Found \(configs.count) enabled configuration(s)")
        for (index, config) in configs.enumerated() {
            let title = config.title
            let pattern = config.urlPattern ?? "none"
            let tags = config.tags ?? "none"
            print("   \(index + 1). \(title) - Pattern: \(pattern), Tags: \(tags)")
            logger.info("   \(index + 1). \(title, privacy: .public)")
        }

        // Get chip URL if available
        guard let chipURL = extractURL(from: chip) else {
            logger.warning("⚠️ [ChipActionConfigurationManager] Chip has no URL in actionData or title")
            print("⚠️ [ChipActionConfigurationManager] Chip has no URL in actionData or title")
            print("   Chip title: \(chip.unwrappedTitle)")
            print("   Chip actionType: \(chip.actionType ?? "nil")")
            print("   Chip actionData: \(chip.actionData?.url ?? "nil")")
            return nil
        }
        
        logger.info("🔗 [ChipActionConfigurationManager] Chip URL: \(chipURL, privacy: .public)")
        print("🔗 [ChipActionConfigurationManager] Chip URL: \(chipURL)")

        // Find first matching configuration
        for config in configs {
            let title = config.title
            let pattern = config.urlPattern ?? "none"
            let tags = config.tags ?? "none"
            logger.info("🔎 [ChipActionConfigurationManager] Checking config: \(title, privacy: .public)")
            print("🔎 [ChipActionConfigurationManager] Checking config: \(title)")
            print("   Pattern: \(pattern)")
            print("   Tags: \(tags)")
            
            if matches(config: config, chipURL: chipURL, chip: chip) {
                logger.info("✅ [ChipActionConfigurationManager] Match found: \(title, privacy: .public)")
                print("✅ [ChipActionConfigurationManager] Match found: \(title)")
                return config
            } else {
                logger.info("❌ [ChipActionConfigurationManager] No match for: \(title, privacy: .public)")
                print("❌ [ChipActionConfigurationManager] No match for: \(title)")
            }
        }
        
        logger.info("⚠️ [ChipActionConfigurationManager] No matching configuration found")
        print("⚠️ [ChipActionConfigurationManager] No matching configuration found")

        return nil
    }

    private func matches(config: ChipActionConfiguration, chipURL: String, chip: Chip) -> Bool {
        // Match by URL pattern
        if let pattern = config.urlPattern, !pattern.isEmpty {
            logger.info("🔍 [ChipActionConfigurationManager] Checking URL pattern: \(pattern, privacy: .public)")
            print("🔍 [ChipActionConfigurationManager] Checking URL pattern: '\(pattern)' against '\(chipURL)'")
            if matchesPattern(pattern: pattern, url: chipURL) {
                logger.info("✅ [ChipActionConfigurationManager] URL pattern matched!")
                print("✅ [ChipActionConfigurationManager] URL pattern matched!")
                return true
            } else {
                logger.info("❌ [ChipActionConfigurationManager] URL pattern did not match")
                print("❌ [ChipActionConfigurationManager] URL pattern did not match")
            }
        } else {
            logger.info("ℹ️ [ChipActionConfigurationManager] No URL pattern configured")
            print("ℹ️ [ChipActionConfigurationManager] No URL pattern configured")
        }

        // Match by tags
        if let configTags = config.tags, !configTags.isEmpty {
            let chipTags = chip.tags
            let configTagsArray = configTags.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            let chipTagsLower = chipTags.map { $0.lowercased() }
            
            logger.info("🔍 [ChipActionConfigurationManager] Checking tags - Config: \(configTags, privacy: .public), Chip: \(chipTags.joined(separator: ", "), privacy: .public)")
            print("🔍 [ChipActionConfigurationManager] Checking tags - Config: '\(configTags)', Chip: '\(chipTags.joined(separator: ", "))'")

            if configTagsArray.contains(where: { chipTagsLower.contains($0) }) {
                logger.info("✅ [ChipActionConfigurationManager] Tag matched!")
                print("✅ [ChipActionConfigurationManager] Tag matched!")
                return true
            } else {
                logger.info("❌ [ChipActionConfigurationManager] No tag match")
                print("❌ [ChipActionConfigurationManager] No tag match")
            }
        } else {
            logger.info("ℹ️ [ChipActionConfigurationManager] No tags configured")
            print("ℹ️ [ChipActionConfigurationManager] No tags configured")
        }

        return false
    }

    private func matchesPattern(pattern: String, url: String) -> Bool {
        let patternLower = pattern.lowercased()
        let urlLower = url.lowercased()
        
        logger.info("🔍 [ChipActionConfigurationManager] Pattern matching - Pattern: '\(patternLower)', URL: '\(urlLower)'")
        print("🔍 [ChipActionConfigurationManager] Pattern matching - Pattern: '\(patternLower)', URL: '\(urlLower)'")

        // Exact match
        if patternLower == urlLower {
            logger.info("✅ [ChipActionConfigurationManager] Exact match!")
            print("✅ [ChipActionConfigurationManager] Exact match!")
            return true
        }

        // Contains match (most common use case)
        if urlLower.contains(patternLower) {
            logger.info("✅ [ChipActionConfigurationManager] Contains match!")
            print("✅ [ChipActionConfigurationManager] Contains match!")
            return true
        }
        
        // Domain matching: Extract host from URL and check domain variations
        if let urlObj = URL(string: url), let urlHost = urlObj.host {
            let urlHostLower = urlHost.lowercased()
            
            // Check if pattern matches the host directly
            if urlHostLower == patternLower || urlHostLower.contains(patternLower) {
                logger.info("✅ [ChipActionConfigurationManager] Host match!")
                print("✅ [ChipActionConfigurationManager] Host match!")
                return true
            }
            
            // Check domain variations for common services
            if matchesDomainVariation(pattern: patternLower, urlHost: urlHostLower) {
                logger.info("✅ [ChipActionConfigurationManager] Domain variation match!")
                print("✅ [ChipActionConfigurationManager] Domain variation match!")
                return true
            }
        }

        // Wildcard matching
        if patternLower.contains("*") {
            let regexPattern = NSRegularExpression.escapedPattern(for: patternLower)
                .replacingOccurrences(of: "\\*", with: ".*")
            logger.info("🔍 [ChipActionConfigurationManager] Trying wildcard regex: '\(regexPattern)'")
            print("🔍 [ChipActionConfigurationManager] Trying wildcard regex: '\(regexPattern)'")
            if let regex = try? NSRegularExpression(pattern: regexPattern, options: .caseInsensitive) {
                let range = NSRange(location: 0, length: urlLower.utf16.count)
                let matched = regex.firstMatch(in: urlLower, options: [], range: range) != nil
                if matched {
                    logger.info("✅ [ChipActionConfigurationManager] Wildcard match!")
                    print("✅ [ChipActionConfigurationManager] Wildcard match!")
                } else {
                    logger.info("❌ [ChipActionConfigurationManager] Wildcard did not match")
                    print("❌ [ChipActionConfigurationManager] Wildcard did not match")
                }
                return matched
            }
        }
        
        logger.info("❌ [ChipActionConfigurationManager] Pattern did not match")
        print("❌ [ChipActionConfigurationManager] Pattern did not match")

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
