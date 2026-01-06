import Foundation
import Markdown

/// Parses markdown files into chip data structures
final class MarkdownParser {

    private let frontmatterParser = FrontmatterParser()
    private let tagExtractor = TagExtractor()

    /// Result of parsing a markdown file
    struct ParseResult {
        let frontmatter: Frontmatter?
        let chips: [ParsedChip]
        let rawContent: String
    }

    /// A parsed chip before being saved to Core Data
    struct ParsedChip {
        let title: String
        let rawMarkdown: String
        let sectionTitle: String?
        let url: URL?
        let tags: [String]
        let actionTags: [TagExtractor.ActionTag]
        let isTaskItem: Bool
        let isCompleted: Bool
        let sortOrder: Int

        /// Computed action type based on content
        var actionType: String {
            if actionTags.contains(where: { $0.type == .timer }) {
                return "timer"
            } else if actionTags.contains(where: { $0.type == .app }) {
                return "app"
            } else if url != nil {
                return "url"
            }
            return "custom"
        }

        /// Generate action payload JSON
        var actionPayload: String {
            var payload: [String: Any] = [:]

            if let url = url {
                payload["url"] = url.absoluteString
            }

            if let appTag = actionTags.first(where: { $0.type == .app }) {
                payload["preferredApp"] = appTag.value
            }

            if let durationTag = actionTags.first(where: { $0.type == .duration }) {
                payload["duration"] = parseDuration(durationTag.value ?? "")
            }

            guard let jsonData = try? JSONSerialization.data(withJSONObject: payload),
                  let jsonString = String(data: jsonData, encoding: .utf8) else {
                return "{}"
            }
            return jsonString
        }

        /// Generate metadata JSON
        var metadataJSON: String {
            var metadata: [String: Any] = [:]

            if !tags.isEmpty {
                metadata["tags"] = tags
            }

            if let repeatTag = actionTags.first(where: { $0.type == .repeat }) {
                metadata["repeatCount"] = Int(repeatTag.value ?? "") ?? 0
            }

            if let durationTag = actionTags.first(where: { $0.type == .duration }) {
                metadata["duration"] = durationTag.value
            }

            guard let jsonData = try? JSONSerialization.data(withJSONObject: metadata),
                  let jsonString = String(data: jsonData, encoding: .utf8) else {
                return "{}"
            }
            return jsonString
        }

        private func parseDuration(_ value: String) -> Int {
            // Parse duration strings like "30m", "1h", "45s"
            let pattern = #"(\d+)([smh])"#
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)),
                  let numberRange = Range(match.range(at: 1), in: value),
                  let unitRange = Range(match.range(at: 2), in: value),
                  let number = Int(value[numberRange]) else {
                return 0
            }

            let unit = String(value[unitRange])
            switch unit {
            case "s": return number
            case "m": return number * 60
            case "h": return number * 3600
            default: return 0
            }
        }
    }

    // MARK: - Public API

    /// Parse markdown content from a string
    func parse(_ content: String) -> ParseResult {
        // Extract frontmatter first
        let (frontmatter, bodyContent) = frontmatterParser.parse(content)

        // Parse the markdown body
        let document = Document(parsing: bodyContent)
        var chips: [ParsedChip] = []
        var currentSection: String? = nil
        var sortOrder = 0

        // Walk through the document
        for block in document.children {
            if let heading = block as? Heading {
                currentSection = extractPlainText(from: heading)
            } else if let list = block as? UnorderedList {
                for item in list.listItems {
                    if let chip = parseListItem(item, section: currentSection, sortOrder: sortOrder) {
                        chips.append(chip)
                        sortOrder += 1
                    }
                }
            } else if let list = block as? OrderedList {
                for item in list.listItems {
                    if let chip = parseListItem(item, section: currentSection, sortOrder: sortOrder) {
                        chips.append(chip)
                        sortOrder += 1
                    }
                }
            }
        }

        return ParseResult(
            frontmatter: frontmatter,
            chips: chips,
            rawContent: content
        )
    }

    /// Parse markdown content from a file URL
    func parse(fileURL: URL) throws -> ParseResult {
        let content = try String(contentsOf: fileURL, encoding: .utf8)
        return self.parse(content)
    }

    /// Convenience method - parse and return just chips array
    func parseChips(_ content: String) -> [ParsedChip] {
        let result = self.parse(content)
        return result.chips
    }

    // MARK: - Private Helpers

    private func parseListItem(_ item: ListItem, section: String?, sortOrder: Int) -> ParsedChip? {
        let rawText = extractPlainText(from: item)
        guard !rawText.isEmpty else { return nil }

        // Check for task list checkbox
        let (isTaskItem, isCompleted, cleanedText) = parseTaskListItem(rawText)

        // Extract link if present
        let (title, url) = extractLink(from: item) ?? (cleanedText, nil)

        // Extract tags from the text
        let tags = tagExtractor.extractHashtags(from: cleanedText)
        let actionTags = tagExtractor.extractActionTags(from: cleanedText)

        // Clean the title (remove tags)
        let cleanTitle = tagExtractor.removeAllTags(from: title)

        return ParsedChip(
            title: cleanTitle.trimmingCharacters(in: .whitespaces),
            rawMarkdown: rawText,
            sectionTitle: section,
            url: url,
            tags: tags,
            actionTags: actionTags,
            isTaskItem: isTaskItem,
            isCompleted: isCompleted,
            sortOrder: sortOrder
        )
    }

    private func parseTaskListItem(_ text: String) -> (isTaskItem: Bool, isCompleted: Bool, cleanedText: String) {
        let trimmed = text.trimmingCharacters(in: .whitespaces)

        if trimmed.hasPrefix("[ ]") {
            return (true, false, String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces))
        } else if trimmed.hasPrefix("[x]") || trimmed.hasPrefix("[X]") {
            return (true, true, String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces))
        }

        return (false, false, text)
    }

    private func extractLink(from item: ListItem) -> (title: String, url: URL)? {
        for child in item.children {
            if let paragraph = child as? Paragraph {
                for inline in paragraph.children {
                    if let link = inline as? Markdown.Link {
                        let title = extractPlainText(from: link)
                        if let destination = link.destination,
                           let url = URL(string: destination) {
                            return (title, url)
                        }
                    }
                }
            }
        }
        return nil
    }

    private func extractPlainText(from markup: some Markup) -> String {
        var result = ""

        func traverse(_ node: some Markup) {
            if let text = node as? Markdown.Text {
                result += text.string
            } else if node is SoftBreak {
                result += " "
            } else {
                for child in node.children {
                    traverse(child)
                }
            }
        }

        traverse(markup)
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Preview/Testing Support

extension MarkdownParser {
    static let sample = """
    ---
    title: Treadmill Workouts
    category: fitness
    default_action: url
    ---

    # Cardio Videos

    - [30 Min HIIT Workout](https://youtube.com/watch?v=abc123) @timer @app:youtube #cardio #hiit
    - [Walking Workout](https://youtube.com/watch?v=def456) #beginner
    - [ ] New video to try @duration:45m
    - [x] ~~Completed video~~

    ## Strength Training

    1. [Upper Body](https://youtube.com/watch?v=ghi789) @duration:45m
    2. [Core Workout](https://youtube.com/watch?v=jkl012) @repeat:3
    """
}
