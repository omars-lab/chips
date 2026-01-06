import Foundation

/// Pre-built action configurations for common apps
struct ActionPreset: Identifiable {
    let id: String
    let name: String
    let icon: String
    let description: String
    let scheme: String
    let path: String
    let defaultParams: [String: String]
    let templateText: String?  // For text-based actions
    let supportedSources: [URLVariableExtractor.ExtractedVariables.SourceType]

    /// All available presets
    static let all: [ActionPreset] = [
        .notePlanToday,
        .notePlanInbox,
        .things3,
        .reminders,
        .obsidian
    ]

    // MARK: - NotePlan Presets

    static let notePlanToday = ActionPreset(
        id: "noteplan-today",
        name: "NotePlan - Add to Today",
        icon: "calendar.badge.plus",
        description: "Add a task to today's note in NotePlan",
        scheme: "noteplan",
        path: "addText",
        defaultParams: [
            "noteDate": "today",
            "mode": "append",
            "openNote": "no"
        ],
        templateText: "- [ ] {{title}} {{url}}",
        supportedSources: URLVariableExtractor.ExtractedVariables.SourceType.allCases
    )

    static let notePlanInbox = ActionPreset(
        id: "noteplan-inbox",
        name: "NotePlan - Add to Inbox",
        icon: "tray.and.arrow.down",
        description: "Add a task to your NotePlan inbox",
        scheme: "noteplan",
        path: "addText",
        defaultParams: [
            "noteTitle": "Inbox",
            "mode": "append",
            "openNote": "no"
        ],
        templateText: "- [ ] {{title}} {{url}}",
        supportedSources: URLVariableExtractor.ExtractedVariables.SourceType.allCases
    )

    // MARK: - Things 3

    static let things3 = ActionPreset(
        id: "things3",
        name: "Things 3 - Add Todo",
        icon: "checkmark.circle",
        description: "Create a new todo in Things 3",
        scheme: "things",
        path: "add",
        defaultParams: [
            "show-quick-entry": "false"
        ],
        templateText: nil,  // Uses title/notes params directly
        supportedSources: URLVariableExtractor.ExtractedVariables.SourceType.allCases
    )

    // MARK: - Reminders

    static let reminders = ActionPreset(
        id: "reminders",
        name: "Reminders - Add Task",
        icon: "list.bullet",
        description: "Create a reminder in Apple Reminders",
        scheme: "x-apple-reminderkit",
        path: "REMCDReminder",
        defaultParams: [:],
        templateText: nil,
        supportedSources: URLVariableExtractor.ExtractedVariables.SourceType.allCases
    )

    // MARK: - Obsidian

    static let obsidian = ActionPreset(
        id: "obsidian",
        name: "Obsidian - Append to Daily",
        icon: "doc.text",
        description: "Append text to today's daily note in Obsidian",
        scheme: "obsidian",
        path: "new",
        defaultParams: [
            "daily": "true",
            "append": "true"
        ],
        templateText: "- [ ] {{title}} [Link]({{url}})",
        supportedSources: URLVariableExtractor.ExtractedVariables.SourceType.allCases
    )

    // MARK: - URL Building

    /// Build the xcallback URL for this preset with given variables
    func buildURL(with variables: [String: String], customText: String? = nil) -> URL? {
        var components = URLComponents()
        components.scheme = scheme
        components.host = "x-callback-url"
        components.path = "/\(path)"

        var queryItems: [URLQueryItem] = []

        // Add default params
        for (key, value) in defaultParams {
            queryItems.append(URLQueryItem(name: key, value: value))
        }

        // Add text content if template exists
        if let template = customText ?? templateText {
            let resolvedText = URLVariableExtractor.resolve(template: template, with: variables)
            queryItems.append(URLQueryItem(name: "text", value: resolvedText))
        }

        // For Things 3, add title and notes separately
        if id == "things3" {
            if let title = variables["title"] {
                queryItems.append(URLQueryItem(name: "title", value: title))
            }
            if let url = variables["url"] {
                queryItems.append(URLQueryItem(name: "notes", value: url))
            }
        }

        components.queryItems = queryItems.isEmpty ? nil : queryItems

        return components.url
    }
}

// MARK: - YouTube-specific templates

extension ActionPreset {
    /// YouTube-optimized templates
    static func youtubeTemplates(for preset: ActionPreset) -> [String] {
        switch preset.id {
        case "noteplan-today", "noteplan-inbox":
            return [
                "- [ ] Watch: {{title}} {{url}}",
                "- [ ] {{title}} (YouTube) {{url}}",
                "- [ ] 🎬 {{title}}\n  - Video: {{url}}",
                "- [ ] {{title}} #youtube"
            ]
        case "obsidian":
            return [
                "- [ ] {{title}} [Watch]({{url}})",
                "- [ ] 🎬 [[{{title}}]] {{url}}",
                "## Watch Later\n- {{title}} {{url}}"
            ]
        default:
            return []
        }
    }
}
