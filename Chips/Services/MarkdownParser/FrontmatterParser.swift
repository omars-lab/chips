import Foundation
import Yams

/// Parses YAML frontmatter from markdown files
final class FrontmatterParser {

    /// Parsed frontmatter data
    struct Frontmatter {
        let title: String?
        let category: String?
        let defaultAction: String?
        let defaultApp: String?
        let customFields: [String: Any]

        init(from dictionary: [String: Any]) {
            self.title = dictionary["title"] as? String
            self.category = dictionary["category"] as? String
            self.defaultAction = dictionary["default_action"] as? String
            self.defaultApp = dictionary["default_app"] as? String

            // Store any additional fields
            var custom = dictionary
            custom.removeValue(forKey: "title")
            custom.removeValue(forKey: "category")
            custom.removeValue(forKey: "default_action")
            custom.removeValue(forKey: "default_app")
            self.customFields = custom
        }
    }

    // MARK: - Public API

    /// Parse frontmatter and body content from markdown
    /// - Parameter content: Raw markdown content
    /// - Returns: Tuple of optional frontmatter and body content
    func parse(_ content: String) -> (Frontmatter?, String) {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)

        // Check if content starts with frontmatter delimiter
        guard trimmed.hasPrefix("---") else {
            return (nil, content)
        }

        // Find the closing delimiter
        let lines = content.components(separatedBy: .newlines)
        var frontmatterLines: [String] = []
        var bodyStartIndex = 0
        var foundOpeningDelimiter = false
        var foundClosingDelimiter = false

        for (index, line) in lines.enumerated() {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)

            if trimmedLine == "---" {
                if !foundOpeningDelimiter {
                    foundOpeningDelimiter = true
                    continue
                } else {
                    foundClosingDelimiter = true
                    bodyStartIndex = index + 1
                    break
                }
            }

            if foundOpeningDelimiter && !foundClosingDelimiter {
                frontmatterLines.append(line)
            }
        }

        guard foundClosingDelimiter else {
            // No valid frontmatter found
            return (nil, content)
        }

        // Parse YAML
        let yamlContent = frontmatterLines.joined(separator: "\n")
        let frontmatter = parseYAML(yamlContent)

        // Extract body
        let bodyLines = Array(lines[bodyStartIndex...])
        let body = bodyLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)

        return (frontmatter, body)
    }

    // MARK: - Private

    private func parseYAML(_ yaml: String) -> Frontmatter? {
        do {
            guard let dictionary = try Yams.load(yaml: yaml) as? [String: Any] else {
                return nil
            }
            return Frontmatter(from: dictionary)
        } catch {
            print("Failed to parse YAML frontmatter: \(error)")
            return nil
        }
    }
}

// MARK: - Frontmatter + Codable-like access

extension FrontmatterParser.Frontmatter {
    /// Get a custom field value
    func customValue<T>(for key: String) -> T? {
        customFields[key] as? T
    }

    /// Check if a custom field exists
    func hasCustomField(_ key: String) -> Bool {
        customFields[key] != nil
    }
}

// MARK: - Frontmatter + JSON

extension FrontmatterParser.Frontmatter {
    /// Convert frontmatter to JSON string for storage
    var asJSON: String? {
        var dict: [String: Any] = customFields

        if let title = title { dict["title"] = title }
        if let category = category { dict["category"] = category }
        if let defaultAction = defaultAction { dict["default_action"] = defaultAction }
        if let defaultApp = defaultApp { dict["default_app"] = defaultApp }

        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let json = String(data: data, encoding: .utf8) else {
            return nil
        }
        return json
    }
}
