import Foundation
import SwiftUI
import CoreData
import os.log
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
        let logger = Logger(subsystem: "com.chips.app", category: "ActionEngine")
        
        // Also print to stdout for debugging
        print("🎯 [ActionEngine] Executing action for chip: \(chip.unwrappedTitle)")
        logger.info("🎯 Executing action for chip: \(chip.unwrappedTitle, privacy: .public)")
        
        // Check for custom configuration first
        if let config = ChipActionConfigurationManager.shared.findConfiguration(for: chip, context: context) {
            print("🎯 [ActionEngine] Found configuration: \(config.title)")
            logger.info("🎯 Found configuration: \(config.title, privacy: .public)")
            executeConfiguredAction(config: config, chip: chip, context: context)
            return
        }
        
        // Fall back to default behavior
        let actionType = chip.actionType ?? "url"
        let actionData = chip.actionData
        
        print("🎯 [ActionEngine] Action type: \(actionType)")
        print("🎯 [ActionEngine] Action data URL: \(actionData?.url ?? "nil")")
        logger.info("   Action type: \(actionType, privacy: .public)")
        logger.info("   Action data: \(actionData?.url ?? "nil", privacy: .public)")

        // Log interaction
        logInteraction(chip: chip, action: "opened_\(actionType)", context: context)

        switch actionType {
        case "url":
            print("🎯 [ActionEngine] Executing URL action")
            executeURLAction(actionData: actionData, chip: chip)
        case "timer":
            print("🎯 [ActionEngine] Executing timer action")
            let duration = actionData?.expectedDuration.map { TimeInterval($0) }
            executeTimerAction(chip: chip, expectedDuration: duration)
        case "app":
            print("🎯 [ActionEngine] Executing app action")
            executeAppAction(appName: actionData?.preferredApp, fallbackURL: actionData?.url)
        default:
            print("🎯 [ActionEngine] Executing default action")
            // Try to extract URL from actionData first
            if let urlString = actionData?.url, let url = URL(string: urlString) {
                print("🎯 [ActionEngine] Found URL in actionData: \(urlString)")
                openURL(url)
            } else {
                // Fallback: check if the title itself is a URL
                let title = chip.unwrappedTitle.trimmingCharacters(in: CharacterSet.whitespaces)
                if let url = URL(string: title), url.scheme != nil {
                    print("🎯 [ActionEngine] Title is a URL, opening: \(title)")
                    logger.info("🎯 Title is a URL, opening: \(title, privacy: .public)")
                    openURL(url)
                } else {
                    print("⚠️ [ActionEngine] No URL found for default action")
                    logger.warning("⚠️ No URL found for default action")
                }
            }
        }
    }
    
    private func executeConfiguredAction(config: ChipActionConfiguration, chip: Chip, context: NSManagedObjectContext) {
        let logger = Logger(subsystem: "com.chips.app", category: "ActionEngine")
        
        // Log interaction
        logInteraction(chip: chip, action: "opened_config_\(config.title)", context: context)
        
        // Build and open action URL
        if let actionURL = ChipActionConfigurationManager.shared.buildActionURL(from: config, chip: chip) {
            logger.info("🔗 Opening configured URL: \(actionURL.absoluteString, privacy: .public)")
            openURL(actionURL)
        } else {
            logger.warning("⚠️ Failed to build action URL from configuration")
            // Fallback to chip's original URL
            if let urlString = chip.actionData?.url, let url = URL(string: urlString) {
                openURL(url)
            }
        }
    }

    // MARK: - URL Action

    private func executeURLAction(actionData: ActionPayload?, chip: Chip) {
        let logger = Logger(subsystem: "com.chips.app", category: "ActionEngine")
        
        print("🔗 [ActionEngine] executeURLAction called")
        
        guard let urlString = actionData?.url else {
            print("⚠️ [ActionEngine] No URL string found in actionData")
            logger.warning("⚠️ No URL string found in actionData")
            return
        }
        
        print("🔗 [ActionEngine] URL string: \(urlString)")
        
        guard let url = URL(string: urlString) else {
            print("⚠️ [ActionEngine] Invalid URL string: \(urlString)")
            logger.warning("⚠️ Invalid URL string: \(urlString, privacy: .public)")
            return
        }

        print("🔗 [ActionEngine] Opening URL: \(url.absoluteString)")
        print("🔗 [ActionEngine] URL scheme: \(url.scheme ?? "none")")
        print("🔗 [ActionEngine] URL host: \(url.host ?? "none")")
        logger.info("🔗 Opening URL: \(url.absoluteString, privacy: .public)")
        logger.info("   URL scheme: \(url.scheme ?? "none", privacy: .public)")
        logger.info("   URL host: \(url.host ?? "none", privacy: .public)")

        // Check if we should open in a specific app
        if let preferredApp = actionData?.preferredApp {
            print("🔗 [ActionEngine] Preferred app: \(preferredApp)")
            logger.info("   Preferred app: \(preferredApp, privacy: .public)")
            openInApp(url: url, appName: preferredApp)
        } else {
            print("🔗 [ActionEngine] No preferred app, calling openURL directly")
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
        let logger = Logger(subsystem: "com.chips.app", category: "ActionEngine")
        
        print("🌐 [ActionEngine] Opening URL: \(url.absoluteString)")
        print("🌐 [ActionEngine] Scheme: \(url.scheme ?? "nil")")
        print("🌐 [ActionEngine] Host: \(url.host ?? "nil")")
        logger.info("🌐 Opening URL in default browser: \(url.absoluteString, privacy: .public)")
        logger.info("   Full URL: \(url.absoluteString, privacy: .public)")
        logger.info("   Scheme: \(url.scheme ?? "nil", privacy: .public)")
        logger.info("   Host: \(url.host ?? "nil", privacy: .public)")
        
        // Ensure URL is valid
        guard url.scheme != nil else {
            print("❌ [ActionEngine] Invalid URL: missing scheme")
            logger.error("❌ Invalid URL: missing scheme")
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
            print("✅ [ActionEngine] Executed: /usr/bin/open \(url.absoluteString)")
            logger.info("✅ Executed: /usr/bin/open \(url.absoluteString, privacy: .public)")
            
            // Read output asynchronously
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8), !output.isEmpty {
                print("   [ActionEngine] Output: \(output)")
                logger.info("   Output: \(output, privacy: .public)")
            }
        } catch {
            print("❌ [ActionEngine] Failed to run /usr/bin/open: \(error.localizedDescription)")
            logger.error("❌ Failed to run /usr/bin/open: \(error.localizedDescription, privacy: .public)")
            
            // Fallback to NSWorkspace
            print("⚠️ [ActionEngine] Trying NSWorkspace fallback...")
            logger.info("   Trying NSWorkspace fallback...")
            let success = NSWorkspace.shared.open(url)
            if success {
                print("✅ [ActionEngine] Opened with NSWorkspace fallback")
                logger.info("✅ Opened with NSWorkspace fallback")
            } else {
                print("❌ [ActionEngine] NSWorkspace also failed")
                logger.error("❌ NSWorkspace also failed")
            }
        }
        #endif
    }

    private func openInApp(url: URL, appName: String) {
        let logger = Logger(subsystem: "com.chips.app", category: "ActionEngine")
        
        #if os(macOS)
        // On macOS, YouTube URLs should open in browser, not app scheme
        if appName.lowercased() == "youtube" {
            logger.info("🔗 Opening YouTube URL in browser: \(url.absoluteString, privacy: .public)")
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
                let fallbackLogger = Logger(subsystem: "com.chips.app", category: "ActionEngine")
                fallbackLogger.warning("⚠️ Failed to open app URL, falling back to browser")
                self.openURL(url)
            }
        }
        #elseif os(macOS)
        logger.info("🔗 Attempting to open URL: \(targetURL.absoluteString, privacy: .public)")
        let success = NSWorkspace.shared.open(targetURL)
        if !success {
            logger.warning("⚠️ Failed to open URL with NSWorkspace, trying direct open")
            openURL(url)
        } else {
            logger.info("✅ Successfully opened URL")
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
