import Foundation
import SwiftUI
import CoreData
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// Central engine for executing chip actions
@MainActor
final class ActionEngine: ObservableObject {
    static let shared = ActionEngine()

    @Published var activeTimer: ActiveTimer?

    private init() {}

    // MARK: - Execute Action

    func execute(chip: Chip, context: NSManagedObjectContext) {
        AppLogger.info("🎯 Executing action for chip: \(chip.unwrappedTitle)", category: AppConstants.LoggerCategory.actionEngine)
        
        // Check for custom configuration first
        if let config = ChipActionConfigurationManager.shared.findConfiguration(for: chip, context: context) {
            AppLogger.info("🎯 Found configuration: \(config.title)", category: AppConstants.LoggerCategory.actionEngine)
            executeConfiguredAction(config: config, chip: chip, context: context)
            
            // Fetch metadata after action (async, non-blocking)
            Task {
                await fetchMetadataIfNeeded(for: chip)
            }
            return
        }
        
        // Fall back to default behavior
        let actionType = chip.actionType ?? "url"
        let actionData = chip.actionData
        
        AppLogger.info("   Action type: \(actionType)", category: AppConstants.LoggerCategory.actionEngine)
        AppLogger.info("   Action data: \(actionData?.url ?? "nil")", category: AppConstants.LoggerCategory.actionEngine)

        // Log interaction
        logInteraction(chip: chip, action: "opened_\(actionType)", context: context)

        switch actionType {
        case "url":
            AppLogger.info("🎯 Executing URL action", category: AppConstants.LoggerCategory.actionEngine)
            executeURLAction(actionData: actionData, chip: chip)
        case "timer":
            AppLogger.info("🎯 Executing timer action", category: AppConstants.LoggerCategory.actionEngine)
            let duration = actionData?.expectedDuration.map { TimeInterval($0) }
            executeTimerAction(chip: chip, expectedDuration: duration)
        case "app":
            AppLogger.info("🎯 Executing app action", category: AppConstants.LoggerCategory.actionEngine)
            executeAppAction(appName: actionData?.preferredApp, fallbackURL: actionData?.url)
        default:
            AppLogger.info("🎯 Executing default action", category: AppConstants.LoggerCategory.actionEngine)
            // Try to extract URL from actionData first
            if let urlString = actionData?.url, let url = URL(string: urlString) {
                AppLogger.info("🎯 Found URL in actionData: \(urlString)", category: AppConstants.LoggerCategory.actionEngine)
                openURL(url)
            } else {
                // Fallback: check if the title itself is a URL
                if let urlString = chip.unwrappedTitle.extractURL(), let url = URL(string: urlString) {
                    AppLogger.info("🎯 Title is a URL, opening: \(urlString)", category: AppConstants.LoggerCategory.actionEngine)
                    openURL(url)
                } else {
                    AppLogger.warning("⚠️ No URL found for default action", category: AppConstants.LoggerCategory.actionEngine)
                }
            }
        }
        
        // Fetch metadata after action (async, non-blocking)
        Task {
            await fetchMetadataIfNeeded(for: chip)
        }
    }
    
    // MARK: - Metadata Fetching
    
    private func fetchMetadataIfNeeded(for chip: Chip) async {
        // Extract URL
        let urlFromActionData = chip.actionData?.url
        let urlFromTitle = chip.unwrappedTitle.extractURL()
        let urlString = urlFromActionData ?? urlFromTitle
        
        guard let urlString = urlString, let url = URL(string: urlString) else {
            AppLogger.debug("❌ [ActionEngine] No URL found - skipping metadata fetch", category: AppConstants.LoggerCategory.actionEngine)
            return
        }
        
        AppLogger.info("📡 [ActionEngine] Fetching metadata for URL: \(urlString)", category: AppConstants.LoggerCategory.actionEngine)
        
        let metadata = await URLMetadataFetcher.shared.fetchMetadata(from: url)
        
        if let metadata = metadata {
            AppLogger.info("✅ [ActionEngine] Metadata fetched successfully:", category: AppConstants.LoggerCategory.actionEngine)
            AppLogger.info("   - Title: \(metadata.title ?? "none")", category: AppConstants.LoggerCategory.actionEngine)
            AppLogger.info("   - Description: \(metadata.description ?? "none")", category: AppConstants.LoggerCategory.actionEngine)
            AppLogger.info("   - Site: \(metadata.siteName ?? "none")", category: AppConstants.LoggerCategory.actionEngine)
            AppLogger.info("   - Type: \(metadata.type ?? "none")", category: AppConstants.LoggerCategory.actionEngine)
            AppLogger.info("   - Image URL: \(metadata.imageURL ?? "none")", category: AppConstants.LoggerCategory.actionEngine)
            
            // Update chip with metadata and trigger summarization
            await updateChipWithMetadata(metadata, chip: chip, urlString: urlString)
        } else {
            AppLogger.debug("⚠️ [ActionEngine] Metadata fetch returned nil", category: AppConstants.LoggerCategory.actionEngine)
        }
    }
    
    /// Update chip with metadata and trigger summarization
    private func updateChipWithMetadata(_ urlMetadata: URLMetadataFetcher.URLMetadata, chip: Chip, urlString: String) async {
        // Check if this is a YouTube video
        let isYouTube = urlString.contains("youtube.com") || urlString.contains("youtu.be")
        
        // Get current chip metadata or create new
        var chipMeta = chip.chipMetadata ?? ChipMetadata()
        
        // Store all metadata fields
        chipMeta.metadataTitle = urlMetadata.title
        chipMeta.metadataDescription = urlMetadata.description
        chipMeta.metadataImageURL = urlMetadata.imageURL
        chipMeta.metadataSiteName = urlMetadata.siteName
        chipMeta.metadataType = urlMetadata.type
        
        // If chip title is just the URL and this is YouTube, update chip.title with metadata title
        // IMPORTANT: Also store URL in actionData so it can still be found after title update
        if isYouTube, let metadataTitle = urlMetadata.title {
            let currentTitle = chip.unwrappedTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            if currentTitle == urlString || currentTitle.extractURL() != nil {
                chip.title = metadataTitle
                
                // Store URL in actionData so it can still be extracted after title update
                var actionData = chip.actionData ?? ActionPayload()
                if actionData.url == nil {
                    actionData.url = urlString
                    chip.actionData = actionData
                    AppLogger.info("💾 [ActionEngine] Stored URL in actionData: \(urlString)", category: AppConstants.LoggerCategory.actionEngine)
                }
                
                AppLogger.info("📝 [ActionEngine] Updated chip title with metadata: \(metadataTitle)", category: AppConstants.LoggerCategory.actionEngine)
            }
        } else {
            // For non-YouTube URLs, also ensure URL is stored in actionData if title contains URL
            let currentTitle = chip.unwrappedTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            if currentTitle == urlString || currentTitle.extractURL() != nil {
                var actionData = chip.actionData ?? ActionPayload()
                if actionData.url == nil {
                    actionData.url = urlString
                    chip.actionData = actionData
                    AppLogger.info("💾 [ActionEngine] Stored URL in actionData: \(urlString)", category: AppConstants.LoggerCategory.actionEngine)
                }
            }
        }
        
        // Store metadata in chip.metadata JSON
        chip.chipMetadata = chipMeta
        
        AppLogger.info("   💾 [ActionEngine] Stored metadata in chip.chipMetadata:", category: AppConstants.LoggerCategory.actionEngine)
        AppLogger.info("      - metadataImageURL: \(chipMeta.metadataImageURL ?? "nil")", category: AppConstants.LoggerCategory.actionEngine)
        AppLogger.info("      - metadataTitle: \(chipMeta.metadataTitle ?? "nil")", category: AppConstants.LoggerCategory.actionEngine)
        
        // Save changes
        do {
            try chip.managedObjectContext?.save()
            AppLogger.info("   ✅ [ActionEngine] Chip saved successfully", category: AppConstants.LoggerCategory.actionEngine)
            
            // Verify chip metadata after save
            if let savedMeta = chip.chipMetadata {
                AppLogger.info("   🔍 [ActionEngine] Verification - chip.chipMetadata.metadataImageURL: \(savedMeta.metadataImageURL ?? "nil")", category: AppConstants.LoggerCategory.actionEngine)
            }
        } catch {
            AppLogger.error("❌ [ActionEngine] Failed to save chip metadata: \(error.localizedDescription)", category: AppConstants.LoggerCategory.actionEngine)
        }
        
        // Trigger summarization after metadata is fetched
        Task {
            await ChipSummaryService.shared.generateSummary(
                for: chip,
                description: urlMetadata.description,
                in: chip.managedObjectContext ?? PersistenceController.shared.container.viewContext
            )
        }
    }
    
    private func executeConfiguredAction(config: ChipActionConfiguration, chip: Chip, context: NSManagedObjectContext) {
        // Log interaction
        logInteraction(chip: chip, action: "opened_config_\(config.title)", context: context)

        // Build all action URLs
        let actionURLs = ChipActionConfigurationManager.shared.buildActionURLs(from: config, chip: chip)

        if actionURLs.isEmpty {
            AppLogger.warning("⚠️ No actions configured, falling back to original URL", category: AppConstants.LoggerCategory.actionEngine)
            if let urlString = chip.actionData?.url, let url = URL(string: urlString) {
                openURL(url)
            }
            return
        }

        AppLogger.info("🎬 Executing \(actionURLs.count) action(s) for config: \(config.title)", category: AppConstants.LoggerCategory.actionEngine)

        // Execute actions in sequence with delays
        executeActionsSequentially(actionURLs, index: 0)
    }

    private func executeActionsSequentially(_ actions: [(action: ChipActionItem, url: URL?)], index: Int) {
        guard index < actions.count else { return }

        let (action, url) = actions[index]

        // Apply delay if specified
        let delay = action.delay ?? 0

        let executeAction = { [weak self] in
            guard let self = self else { return }

            if let url = url {
                AppLogger.info("  [\(index + 1)/\(actions.count)] \(action.name): \(url.absoluteString)", category: AppConstants.LoggerCategory.actionEngine)
                self.openURL(url)
            } else {
                AppLogger.warning("  [\(index + 1)/\(actions.count)] \(action.name): No URL", category: AppConstants.LoggerCategory.actionEngine)
            }

            // Execute next action
            if index + 1 < actions.count {
                // Small delay between actions to prevent overwhelming the system
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.executeActionsSequentially(actions, index: index + 1)
                }
            }
        }

        if delay > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { @MainActor in
                executeAction()
            }
        } else {
            executeAction()
        }
    }

    // MARK: - URL Action

    private func executeURLAction(actionData: ActionPayload?, chip: Chip) {
        AppLogger.info("🔗 executeURLAction called", category: AppConstants.LoggerCategory.actionEngine)
        
        guard let urlString = actionData?.url else {
            AppLogger.warning("⚠️ No URL string found in actionData", category: AppConstants.LoggerCategory.actionEngine)
            return
        }
        
        guard let url = URL(string: urlString) else {
            AppLogger.warning("⚠️ Invalid URL string: \(urlString)", category: AppConstants.LoggerCategory.actionEngine)
            return
        }

        AppLogger.info("🔗 Opening URL: \(url.absoluteString)", category: AppConstants.LoggerCategory.actionEngine)
        AppLogger.info("   URL scheme: \(url.scheme ?? "none")", category: AppConstants.LoggerCategory.actionEngine)
        AppLogger.info("   URL host: \(url.host ?? "none")", category: AppConstants.LoggerCategory.actionEngine)

        // Check if we should open in a specific app
        if let preferredApp = actionData?.preferredApp {
            AppLogger.info("   Preferred app: \(preferredApp)", category: AppConstants.LoggerCategory.actionEngine)
            openInApp(url: url, appName: preferredApp)
        } else {
            AppLogger.info("🔗 No preferred app, calling openURL directly", category: AppConstants.LoggerCategory.actionEngine)
            openURL(url)
        }

        // Start timer if chip has timer tag
        if chip.hasTimerTag {
            let duration = actionData?.expectedDuration.map { TimeInterval($0) }
            startTimer(for: chip, expectedDuration: duration)
        }
    }

    // MARK: - Timer Action

    private func executeTimerAction(chip: Chip, expectedDuration: TimeInterval?) {
        if activeTimer?.chipID == chip.id {
            // Toggle existing timer
            if activeTimer?.isRunning == true {
                pauseTimer()
            } else {
                resumeTimer()
            }
        } else {
            // Start new timer
            startTimer(for: chip, expectedDuration: expectedDuration)
        }
    }

    // MARK: - App Action

    private func executeAppAction(appName: String?, fallbackURL: String?) {
        guard let appName = appName else {
            if let urlString = fallbackURL, let url = URL(string: urlString) {
                openURL(url)
            }
            return
        }

        let appScheme = appURLScheme(for: appName)
        if let schemeURL = URL(string: "\(appScheme)://") {
            #if os(iOS)
            UIApplication.shared.open(schemeURL) { success in
                if !success, let urlString = fallbackURL, let url = URL(string: urlString) {
                    self.openURL(url)
                }
            }
            #elseif os(macOS)
            if !NSWorkspace.shared.open(schemeURL) {
                if let urlString = fallbackURL, let url = URL(string: urlString) {
                    openURL(url)
                }
            }
            #endif
        }
    }

    // MARK: - Open URL

    private func openURL(_ url: URL) {
        #if os(iOS)
        UIApplication.shared.open(url)
        #elseif os(macOS)
        AppLogger.info("🌐 Opening URL in default browser: \(url.absoluteString)", category: AppConstants.LoggerCategory.actionEngine)
        AppLogger.info("   Full URL: \(url.absoluteString)", category: AppConstants.LoggerCategory.actionEngine)
        AppLogger.info("   Scheme: \(url.scheme ?? "nil")", category: AppConstants.LoggerCategory.actionEngine)
        AppLogger.info("   Host: \(url.host ?? "nil")", category: AppConstants.LoggerCategory.actionEngine)
        
        // Ensure URL is valid
        guard url.scheme != nil else {
            AppLogger.error("❌ Invalid URL: missing scheme", category: AppConstants.LoggerCategory.actionEngine)
            return
        }
        
        // Use /usr/bin/open directly - most reliable method
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = [url.absoluteString]
        
        // Set up to capture output
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        
        do {
            try task.run()
            AppLogger.info("✅ Executed: /usr/bin/open \(url.absoluteString)", category: AppConstants.LoggerCategory.actionEngine)
            
            // Read output asynchronously
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8), !output.isEmpty {
                AppLogger.info("   Output: \(output)", category: AppConstants.LoggerCategory.actionEngine)
            }
        } catch {
            AppLogger.error("❌ Failed to run /usr/bin/open: \(error.localizedDescription)", category: AppConstants.LoggerCategory.actionEngine)
            
            // Fallback to NSWorkspace
            AppLogger.info("   Trying NSWorkspace fallback...", category: AppConstants.LoggerCategory.actionEngine)
            let success = NSWorkspace.shared.open(url)
            if success {
                AppLogger.info("✅ Opened with NSWorkspace fallback", category: AppConstants.LoggerCategory.actionEngine)
            } else {
                AppLogger.error("❌ NSWorkspace also failed", category: AppConstants.LoggerCategory.actionEngine)
            }
        }
        #endif
    }

    private func openInApp(url: URL, appName: String) {
        #if os(macOS)
        // On macOS, YouTube URLs should open in browser, not app scheme
        if appName.lowercased() == "youtube" {
            AppLogger.info("🔗 Opening YouTube URL in browser: \(url.absoluteString)", category: AppConstants.LoggerCategory.actionEngine)
            openURL(url)
            return
        }
        #endif
        
        var appURL: URL?

        switch appName.lowercased() {
        case "youtube":
            #if os(iOS)
            appURL = youtubeAppURL(from: url)
            #else
            // macOS: always use browser
            appURL = url
            #endif
        case "vlc":
            appURL = URL(string: "vlc://\(url.absoluteString)")
        case "safari":
            appURL = url
        default:
            appURL = url
        }

        guard let targetURL = appURL else {
            openURL(url)
            return
        }

        #if os(iOS)
        UIApplication.shared.open(targetURL) { success in
            if !success {
                AppLogger.warning("⚠️ Failed to open app URL, falling back to browser", category: AppConstants.LoggerCategory.actionEngine)
                self.openURL(url)
            }
        }
        #elseif os(macOS)
        AppLogger.info("🔗 Attempting to open URL: \(targetURL.absoluteString)", category: AppConstants.LoggerCategory.actionEngine)
        let success = NSWorkspace.shared.open(targetURL)
        if !success {
            AppLogger.warning("⚠️ Failed to open URL with NSWorkspace, trying direct open", category: AppConstants.LoggerCategory.actionEngine)
            openURL(url)
        } else {
            AppLogger.info("✅ Successfully opened URL", category: AppConstants.LoggerCategory.actionEngine)
        }
        #endif
    }

    private func youtubeAppURL(from url: URL) -> URL? {
        // Extract video ID from various YouTube URL formats
        let urlString = url.absoluteString
        var videoID: String?

        // youtube.com/watch?v=VIDEO_ID
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let vParam = components.queryItems?.first(where: { $0.name == "v" })?.value {
            videoID = vParam
        }
        // youtu.be/VIDEO_ID
        else if url.host == "youtu.be" {
            videoID = url.pathComponents.last
        }
        // youtube.com/embed/VIDEO_ID
        else if urlString.contains("/embed/") {
            videoID = url.pathComponents.last
        }

        if let videoID = videoID {
            return URL(string: "youtube://watch?v=\(videoID)")
        }
        return nil
    }

    private func appURLScheme(for appName: String) -> String {
        switch appName.lowercased() {
        case "youtube": return "youtube"
        case "safari": return "http"
        case "vlc": return "vlc"
        case "music": return "music"
        case "podcasts": return "podcasts"
        case "spotify": return "spotify"
        default: return appName
        }
    }

    // MARK: - Timer Management

    func startTimer(for chip: Chip, expectedDuration: TimeInterval?) {
        _ = stopTimer()

        activeTimer = ActiveTimer(
            chipID: chip.id ?? UUID(),
            chipTitle: chip.unwrappedTitle,
            expectedDuration: expectedDuration,
            startTime: Date()
        )
        activeTimer?.start()
    }

    func pauseTimer() {
        activeTimer?.pause()
    }

    func resumeTimer() {
        activeTimer?.resume()
    }

    func stopTimer() -> TimeInterval? {
        guard let timer = activeTimer else { return nil }
        let elapsed = timer.elapsedTime
        timer.stop()
        activeTimer = nil
        return elapsed
    }

    // MARK: - Interaction Logging

    private func logInteraction(chip: Chip, action: String, context: NSManagedObjectContext, duration: TimeInterval? = nil, notes: String? = nil) {
        let interaction = ChipInteraction(context: context)
        interaction.id = UUID()
        interaction.chip = chip
        interaction.timestamp = Date()
        interaction.actionTaken = action
        interaction.deviceName = Self.deviceName

        if let duration = duration {
            interaction.duration = Int32(duration)
        }
        if let notes = notes {
            interaction.notes = notes
        }

        try? context.save()
    }

    func logTimerCompletion(chip: Chip, duration: TimeInterval, context: NSManagedObjectContext) {
        logInteraction(chip: chip, action: "timer_completed", context: context, duration: duration)
    }

    // MARK: - Device Name

    static var deviceName: String {
        #if os(iOS)
        return UIDevice.current.name
        #elseif os(macOS)
        return Host.current().localizedName ?? "Mac"
        #endif
    }
}

// MARK: - Active Timer

class ActiveTimer: ObservableObject {
    let chipID: UUID
    let chipTitle: String
    let expectedDuration: TimeInterval?
    let startTime: Date

    @Published var elapsedTime: TimeInterval = 0
    @Published var isRunning: Bool = false

    private var timer: Timer?
    private var pausedTime: TimeInterval = 0

    init(chipID: UUID, chipTitle: String, expectedDuration: TimeInterval?, startTime: Date) {
        self.chipID = chipID
        self.chipTitle = chipTitle
        self.expectedDuration = expectedDuration
        self.startTime = startTime
    }

    func start() {
        isRunning = true
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, self.isRunning else { return }
            self.elapsedTime += 1
        }
    }

    func pause() {
        isRunning = false
        pausedTime = elapsedTime
    }

    func resume() {
        isRunning = true
    }

    func stop() {
        isRunning = false
        timer?.invalidate()
        timer = nil
    }

    var progress: Double {
        guard let expected = expectedDuration, expected > 0 else { return 0 }
        return min(elapsedTime / expected, 1.0)
    }

    var formattedElapsed: String {
        let minutes = Int(elapsedTime) / 60
        let seconds = Int(elapsedTime) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var formattedRemaining: String? {
        guard let expected = expectedDuration else { return nil }
        let remaining = max(0, expected - elapsedTime)
        let minutes = Int(remaining) / 60
        let seconds = Int(remaining) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Chip Extension for Timer Tag

extension Chip {
    var hasTimerTag: Bool {
        guard let metadata = metadata,
              let data = metadata.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let actionTags = json["actionTags"] as? [[String: Any]] else {
            return false
        }
        return actionTags.contains { ($0["type"] as? String) == "timer" }
    }
}
