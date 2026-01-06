import Foundation
import SwiftUI
import CoreData
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// Central engine for executing chip actions
final class ActionEngine: ObservableObject {
    static let shared = ActionEngine()

    @Published var activeTimer: ActiveTimer?

    private init() {}

    // MARK: - Execute Action

    func execute(chip: Chip, context: NSManagedObjectContext) {
        let actionType = chip.actionType ?? "url"
        let actionData = chip.actionData

        // Log interaction
        logInteraction(chip: chip, action: "opened_\(actionType)", context: context)

        switch actionType {
        case "url":
            executeURLAction(actionData: actionData, chip: chip)
        case "timer":
            let duration = actionData?.expectedDuration.map { TimeInterval($0) }
            executeTimerAction(chip: chip, expectedDuration: duration)
        case "app":
            executeAppAction(appName: actionData?.preferredApp, fallbackURL: actionData?.url)
        default:
            // Default to URL if available
            if let urlString = actionData?.url, let url = URL(string: urlString) {
                openURL(url)
            }
        }
    }

    // MARK: - URL Action

    private func executeURLAction(actionData: ActionPayload?, chip: Chip) {
        guard let urlString = actionData?.url, let url = URL(string: urlString) else { return }

        // Check if we should open in a specific app
        if let preferredApp = actionData?.preferredApp {
            openInApp(url: url, appName: preferredApp)
        } else {
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
        NSWorkspace.shared.open(url)
        #endif
    }

    private func openInApp(url: URL, appName: String) {
        var appURL: URL?

        switch appName.lowercased() {
        case "youtube":
            appURL = youtubeAppURL(from: url)
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
                self.openURL(url)
            }
        }
        #elseif os(macOS)
        if !NSWorkspace.shared.open(targetURL) {
            openURL(url)
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
