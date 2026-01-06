import Foundation
import Combine
import CoreData

/// Monitors the shared container for new items added via Share Extension
final class InboxMonitor: ObservableObject {
    static let shared = InboxMonitor()

    @Published var pendingItemsCount: Int = 0
    @Published var lastImportDate: Date?

    private let appGroupID = "group.com.chips.app"
    private let inboxFileName = "inbox.md"
    private var fileMonitor: DispatchSourceFileSystemObject?
    private var lastCheckDate: Date?

    private init() {
        setupMonitoring()
        checkForNewItems()
    }

    deinit {
        stopMonitoring()
    }

    // MARK: - Container URL

    var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
    }

    var inboxURL: URL? {
        containerURL?.appendingPathComponent(inboxFileName)
    }

    // MARK: - Monitoring

    private func setupMonitoring() {
        // Monitor UserDefaults for share date changes
        if let defaults = UserDefaults(suiteName: appGroupID) {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(userDefaultsDidChange),
                name: UserDefaults.didChangeNotification,
                object: defaults
            )
        }

        // Also set up file system monitoring
        guard let url = inboxURL else { return }

        // Create the file if it doesn't exist
        if !FileManager.default.fileExists(atPath: url.path) {
            try? "".write(to: url, atomically: true, encoding: .utf8)
        }

        let fileDescriptor = open(url.path, O_EVTONLY)
        guard fileDescriptor >= 0 else { return }

        fileMonitor = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .extend],
            queue: .main
        )

        fileMonitor?.setEventHandler { [weak self] in
            self?.checkForNewItems()
        }

        fileMonitor?.setCancelHandler {
            close(fileDescriptor)
        }

        fileMonitor?.resume()
    }

    private func stopMonitoring() {
        fileMonitor?.cancel()
        fileMonitor = nil
    }

    @objc private func userDefaultsDidChange() {
        checkForNewItems()
    }

    // MARK: - Check for New Items

    func checkForNewItems() {
        guard let defaults = UserDefaults(suiteName: appGroupID),
              let lastShareDate = defaults.object(forKey: "lastShareDate") as? Date else {
            return
        }

        // Check if this is newer than our last check
        if let lastCheck = lastCheckDate, lastShareDate <= lastCheck {
            return
        }

        lastCheckDate = lastShareDate

        // Count pending items in inbox
        countPendingItems()
    }

    private func countPendingItems() {
        guard let url = inboxURL,
              let content = try? String(contentsOf: url, encoding: .utf8) else {
            pendingItemsCount = 0
            return
        }

        // Count lines that start with "- " (list items)
        let lines = content.components(separatedBy: .newlines)
        let itemLines = lines.filter { $0.trimmingCharacters(in: .whitespaces).hasPrefix("- ") }
        pendingItemsCount = itemLines.count
    }

    // MARK: - Import Items

    /// Import shared items into the main app as chips
    func importItems(to source: ChipSource, context: NSManagedObjectContext) throws -> [Chip] {
        guard let url = inboxURL else {
            throw InboxError.containerNotFound
        }

        guard FileManager.default.fileExists(atPath: url.path) else {
            return []
        }

        let content = try String(contentsOf: url, encoding: .utf8)
        let parser = MarkdownParser()
        let parsedChips = parser.parseChips(content)

        var importedChips: [Chip] = []

        for (index, parsed) in parsedChips.enumerated() {
            let chip = Chip(context: context)
            chip.id = UUID()
            chip.source = source
            chip.title = parsed.title
            chip.rawMarkdown = parsed.rawMarkdown
            chip.sectionTitle = "Shared Items"
            chip.sortOrder = Int32(index)
            chip.isCompleted = parsed.isCompleted

            // Set action type and payload
            if let url = parsed.url {
                chip.actionType = "url"
                var actionData: [String: Any] = ["url": url.absoluteString]

                // Detect YouTube
                if url.host?.contains("youtube.com") == true || url.host == "youtu.be" {
                    actionData["preferredApp"] = "youtube"
                }

                // Add duration if specified
                if let duration = parsed.actionTags.first(where: { $0.type == .duration })?.value,
                   let minutes = Int(duration.replacingOccurrences(of: "m", with: "")) {
                    actionData["duration"] = minutes * 60
                }

                if let jsonData: Data = try? JSONSerialization.data(withJSONObject: actionData),
                   let jsonString = String(data: jsonData, encoding: .utf8) {
                    chip.actionPayload = jsonString
                }
            }

            // Set metadata
            var metadata: [String: Any] = [:]
            if !parsed.tags.isEmpty {
                metadata["tags"] = parsed.tags
            }
            if !parsed.actionTags.isEmpty {
                metadata["actionTags"] = parsed.actionTags.map { ["type": $0.type.rawValue, "value": $0.value ?? ""] }
            }
            if !metadata.isEmpty {
                if let jsonData: Data = try? JSONSerialization.data(withJSONObject: metadata),
                   let jsonString = String(data: jsonData, encoding: .utf8) {
                    chip.metadata = jsonString
                }
            }

            importedChips.append(chip)
        }

        // Clear the inbox file after import
        if !importedChips.isEmpty {
            clearInbox()
            lastImportDate = Date()
        }

        try context.save()
        pendingItemsCount = 0

        return importedChips
    }

    /// Import items directly into a new or existing source
    func importToNewSource(named name: String, context: NSManagedObjectContext) throws -> (source: ChipSource, chips: [Chip]) {
        let source = ChipSource(context: context)
        source.id = UUID()
        source.name = name
        source.lastParsed = Date()
        source.iCloudPath = "shared://\(name)"

        let chips = try importItems(to: source, context: context)
        return (source, chips)
    }

    // MARK: - Clear Inbox

    func clearInbox() {
        guard let url = inboxURL else { return }

        let header = """
        ---
        title: Inbox
        category: inbox
        ---

        # Shared Items


        """

        try? header.write(to: url, atomically: true, encoding: .utf8)
        pendingItemsCount = 0
    }

    // MARK: - Preview Content

    func previewContent() -> String? {
        guard let url = inboxURL else { return nil }
        return try? String(contentsOf: url, encoding: .utf8)
    }
}

// MARK: - Errors

enum InboxError: LocalizedError {
    case containerNotFound
    case parseError
    case importFailed

    var errorDescription: String? {
        switch self {
        case .containerNotFound:
            return "Shared container not found. Please ensure app groups are configured."
        case .parseError:
            return "Failed to parse inbox content."
        case .importFailed:
            return "Failed to import items."
        }
    }
}
