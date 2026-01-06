import Foundation
import CoreData
import Combine

/// Manages markdown file sources from iCloud Drive
@MainActor
final class MarkdownSourceManager: ObservableObject {

    static let shared = MarkdownSourceManager()

    // MARK: - Published Properties

    @Published private(set) var sources: [ChipSource] = []
    @Published private(set) var isMonitoring = false
    @Published private(set) var lastError: Error?

    // MARK: - Dependencies

    private let parser = MarkdownParser()
    private var metadataQuery: NSMetadataQuery?
    private var monitoredURLs: Set<URL> = []
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    private init() {
        setupNotifications()
    }

    // MARK: - Public API

    /// Add a new source folder
    func addSource(url: URL, name: String? = nil, context: NSManagedObjectContext) async throws {
        // Start accessing security-scoped resource
        guard url.startAccessingSecurityScopedResource() else {
            throw SourceManagerError.accessDenied
        }

        defer {
            url.stopAccessingSecurityScopedResource()
        }

        // Create bookmark for persistent access
        let bookmarkData = try url.bookmarkData(
            options: .minimalBookmark,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )

        // Store bookmark in UserDefaults
        var bookmarks = UserDefaults.standard.dictionary(forKey: "sourceBookmarks") as? [String: Data] ?? [:]
        bookmarks[url.path] = bookmarkData
        UserDefaults.standard.set(bookmarks, forKey: "sourceBookmarks")

        // Parse the source
        try await parseSource(url: url, name: name, context: context)
    }

    /// Remove a source
    func removeSource(_ source: ChipSource, context: NSManagedObjectContext) {
        if let path = source.iCloudPath {
            var bookmarks = UserDefaults.standard.dictionary(forKey: "sourceBookmarks") as? [String: Data] ?? [:]
            bookmarks.removeValue(forKey: path)
            UserDefaults.standard.set(bookmarks, forKey: "sourceBookmarks")
        }

        context.delete(source)
        try? context.save()
    }

    /// Refresh all sources
    func refreshAllSources(context: NSManagedObjectContext) async {
        let fetchRequest = ChipSource.fetchRequest()
        guard let sources = try? context.fetch(fetchRequest) else { return }

        for source in sources {
            guard let path = source.iCloudPath,
                  let url = resolveBookmark(for: path) else { continue }

            do {
                try await parseSource(url: url, existingSource: source, context: context)
            } catch {
                print("Failed to refresh source \(source.unwrappedName): \(error)")
            }
        }
    }

    /// Start monitoring for file changes
    func startMonitoring() {
        guard !isMonitoring else { return }

        metadataQuery = NSMetadataQuery()
        metadataQuery?.predicate = NSPredicate(format: "%K LIKE '*.md'", NSMetadataItemFSNameKey)
        metadataQuery?.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(metadataQueryDidUpdate),
            name: .NSMetadataQueryDidUpdate,
            object: metadataQuery
        )

        metadataQuery?.start()
        isMonitoring = true
    }

    /// Stop monitoring for file changes
    func stopMonitoring() {
        metadataQuery?.stop()
        metadataQuery = nil
        isMonitoring = false
    }

    // MARK: - Private Methods

    private func setupNotifications() {
        // Listen for iCloud account changes
        NotificationCenter.default.publisher(for: NSUbiquitousKeyValueStore.didChangeExternallyNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    let context = PersistenceController.shared.viewContext
                    await self?.refreshAllSources(context: context)
                }
            }
            .store(in: &cancellables)
    }

    @objc private func metadataQueryDidUpdate(_ notification: Notification) {
        guard let query = notification.object as? NSMetadataQuery else { return }

        query.disableUpdates()
        defer { query.enableUpdates() }

        // Check for changed files
        for item in query.results as? [NSMetadataItem] ?? [] {
            guard let url = item.value(forAttribute: NSMetadataItemURLKey) as? URL else { continue }

            if monitoredURLs.contains(url) {
                Task { @MainActor in
                    let context = PersistenceController.shared.viewContext
                    try? await self.handleFileChange(url: url, context: context)
                }
            }
        }
    }

    private func handleFileChange(url: URL, context: NSManagedObjectContext) async throws {
        // Find the existing source
        let fetchRequest = ChipSource.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "iCloudPath == %@", url.path)

        guard let source = try? context.fetch(fetchRequest).first else { return }

        // Check if content actually changed
        let content = try String(contentsOf: url, encoding: .utf8)
        let newChecksum = content.hashValue.description

        if source.checksum == newChecksum {
            return // No changes
        }

        // Re-parse the source
        try await parseSource(url: url, existingSource: source, context: context)
    }

    private func parseSource(
        url: URL,
        name: String? = nil,
        existingSource: ChipSource? = nil,
        context: NSManagedObjectContext
    ) async throws {
        // Read file content
        let content = try String(contentsOf: url, encoding: .utf8)
        let checksum = content.hashValue.description

        // Parse markdown
        let result = parser.parse(content)

        // Create or update source
        let source = existingSource ?? ChipSource(context: context)

        if existingSource == nil {
            source.id = UUID()
        }

        source.name = name ?? result.frontmatter?.title ?? url.deletingPathExtension().lastPathComponent
        source.iCloudPath = url.path
        source.lastParsed = Date()
        source.checksum = checksum

        // Get existing chips for matching
        let existingChips = source.chipsArray
        var existingChipsByContent: [String: Chip] = [:]
        for chip in existingChips {
            if let raw = chip.rawMarkdown {
                existingChipsByContent[raw] = chip
            }
        }

        // Update or create chips
        var processedChipIDs: Set<UUID> = []

        for parsedChip in result.chips {
            let chip: Chip

            // Try to match existing chip by raw content
            if let existing = existingChipsByContent[parsedChip.rawMarkdown] {
                chip = existing
            } else {
                chip = Chip(context: context)
                chip.id = UUID()
                chip.createdAt = Date()
            }

            chip.title = parsedChip.title
            chip.rawMarkdown = parsedChip.rawMarkdown
            chip.sectionTitle = parsedChip.sectionTitle
            chip.actionType = parsedChip.actionType
            chip.actionPayload = parsedChip.actionPayload
            chip.metadata = parsedChip.metadataJSON
            chip.sortOrder = Int32(parsedChip.sortOrder)
            chip.source = source

            // Only update completion from task list if it's a task item
            if parsedChip.isTaskItem {
                chip.isCompleted = parsedChip.isCompleted
                if parsedChip.isCompleted && chip.completedAt == nil {
                    chip.completedAt = Date()
                }
            }

            if let id = chip.id {
                processedChipIDs.insert(id)
            }
        }

        // Remove chips that are no longer in the file
        for chip in existingChips {
            if let id = chip.id, !processedChipIDs.contains(id) {
                // Keep chips with interaction history, just mark as orphaned
                if chip.interactionCount > 0 {
                    chip.source = nil // Orphan but keep
                } else {
                    context.delete(chip)
                }
            }
        }

        // Save
        try context.save()

        // Add to monitored URLs
        monitoredURLs.insert(url)
    }

    private func resolveBookmark(for path: String) -> URL? {
        guard let bookmarks = UserDefaults.standard.dictionary(forKey: "sourceBookmarks") as? [String: Data],
              let bookmarkData = bookmarks[path] else {
            return nil
        }

        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: bookmarkData,
            options: [],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else {
            return nil
        }

        return url
    }
}

// MARK: - Errors

enum SourceManagerError: LocalizedError {
    case accessDenied
    case fileNotFound
    case parseError(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Access to the folder was denied. Please try selecting it again."
        case .fileNotFound:
            return "The markdown file could not be found."
        case .parseError(let error):
            return "Failed to parse markdown: \(error.localizedDescription)"
        }
    }
}

// MARK: - Frontmatter Type Alias

typealias Frontmatter = FrontmatterParser.Frontmatter
