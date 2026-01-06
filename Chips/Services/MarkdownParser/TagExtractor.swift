import Foundation

/// Extracts inline tags from markdown text
final class TagExtractor {

    /// Types of action tags supported
    enum ActionTagType: String, CaseIterable {
        case timer      // @timer
        case app        // @app:youtube
        case duration   // @duration:30m
        case `repeat`   // @repeat:5

        var pattern: String {
            switch self {
            case .timer:
                return #"@timer\b"#
            case .app:
                return #"@app:(\w+)"#
            case .duration:
                return #"@duration:(\d+[smh])"#
            case .repeat:
                return #"@repeat:(\d+)"#
            }
        }
    }

    /// Represents an extracted action tag
    struct ActionTag: Equatable {
        let type: ActionTagType
        let value: String?
        let rawMatch: String
    }

    // MARK: - Hashtag Extraction

    /// Extract hashtags (#tag) from text
    func extractHashtags(from text: String) -> [String] {
        let pattern = #"#(\w+)"#

        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return []
        }

        let range = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, range: range)

        return matches.compactMap { match in
            guard let tagRange = Range(match.range(at: 1), in: text) else {
                return nil
            }
            return String(text[tagRange])
        }
    }

    // MARK: - Action Tag Extraction

    /// Extract all action tags (@timer, @app:x, etc.) from text
    func extractActionTags(from text: String) -> [ActionTag] {
        var tags: [ActionTag] = []

        for tagType in ActionTagType.allCases {
            let extracted = extractActionTag(type: tagType, from: text)
            tags.append(contentsOf: extracted)
        }

        return tags
    }

    /// Extract a specific type of action tag
    func extractActionTag(type: ActionTagType, from text: String) -> [ActionTag] {
        guard let regex = try? NSRegularExpression(pattern: type.pattern) else {
            return []
        }

        let range = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, range: range)

        return matches.compactMap { match in
            guard let fullRange = Range(match.range, in: text) else {
                return nil
            }

            let rawMatch = String(text[fullRange])

            // Extract value if present (for tags like @app:youtube)
            var value: String? = nil
            if match.numberOfRanges > 1,
               let valueRange = Range(match.range(at: 1), in: text) {
                value = String(text[valueRange])
            }

            return ActionTag(type: type, value: value, rawMatch: rawMatch)
        }
    }

    // MARK: - Tag Removal

    /// Remove all tags (hashtags and action tags) from text
    func removeAllTags(from text: String) -> String {
        var result = text

        // Remove action tags
        for tagType in ActionTagType.allCases {
            result = removePattern(tagType.pattern, from: result)
        }

        // Remove hashtags
        result = removePattern(#"#\w+"#, from: result)

        // Clean up multiple spaces
        result = result.replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)

        return result.trimmingCharacters(in: .whitespaces)
    }

    /// Remove hashtags only
    func removeHashtags(from text: String) -> String {
        removePattern(#"#\w+"#, from: text)
    }

    /// Remove action tags only
    func removeActionTags(from text: String) -> String {
        var result = text
        for tagType in ActionTagType.allCases {
            result = removePattern(tagType.pattern, from: result)
        }
        return result.trimmingCharacters(in: .whitespaces)
    }

    // MARK: - Private Helpers

    private func removePattern(_ pattern: String, from text: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return text
        }

        let range = NSRange(text.startIndex..., in: text)
        return regex.stringByReplacingMatches(in: text, range: range, withTemplate: "")
    }
}

// MARK: - Convenience Extensions

extension TagExtractor.ActionTag: CustomStringConvertible {
    var description: String {
        if let value = value {
            return "@\(type.rawValue):\(value)"
        }
        return "@\(type.rawValue)"
    }
}

extension Array where Element == TagExtractor.ActionTag {
    /// Check if array contains a specific tag type
    func contains(type: TagExtractor.ActionTagType) -> Bool {
        contains { $0.type == type }
    }

    /// Get the first tag of a specific type
    func first(ofType type: TagExtractor.ActionTagType) -> TagExtractor.ActionTag? {
        first { $0.type == type }
    }
}
