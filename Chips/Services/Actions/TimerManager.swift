import Foundation
import SwiftUI
import Combine
#if os(iOS)
import UIKit
import UserNotifications
#elseif os(macOS)
import AppKit
import UserNotifications
#endif

/// Manages background timer tracking with notifications
final class TimerManager: ObservableObject {
    static let shared = TimerManager()

    @Published var activeTimer: ManagedTimer?
    @Published var isTimerViewExpanded: Bool = false

    #if os(iOS)
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
    #endif
    private var cancellables = Set<AnyCancellable>()

    private init() {
        setupNotifications()
    }

    // MARK: - Timer Control

    func startTimer(chipID: UUID, chipTitle: String, expectedDuration: TimeInterval?) {
        // Stop any existing timer
        _ = stopTimer()

        activeTimer = ManagedTimer(
            chipID: chipID,
            chipTitle: chipTitle,
            expectedDuration: expectedDuration
        )
        activeTimer?.start()

        // Schedule completion notification if duration is known
        if let duration = expectedDuration {
            scheduleCompletionNotification(title: chipTitle, delay: duration)
        }

        #if os(iOS)
        beginBackgroundTask()
        #endif
    }

    func pauseTimer() {
        activeTimer?.pause()
        cancelScheduledNotifications()
    }

    func resumeTimer() {
        activeTimer?.resume()

        // Reschedule notification for remaining time
        if let timer = activeTimer, let expected = timer.expectedDuration {
            let remaining = expected - timer.elapsedTime
            if remaining > 0 {
                scheduleCompletionNotification(title: timer.chipTitle, delay: remaining)
            }
        }
    }

    func stopTimer() -> TimerResult? {
        guard let timer = activeTimer else { return nil }

        let result = TimerResult(
            chipID: timer.chipID,
            chipTitle: timer.chipTitle,
            duration: timer.elapsedTime,
            expectedDuration: timer.expectedDuration,
            completedAt: Date()
        )

        timer.stop()
        activeTimer = nil
        cancelScheduledNotifications()

        #if os(iOS)
        endBackgroundTask()
        #endif

        return result
    }

    // MARK: - Background Task (iOS)

    #if os(iOS)
    private func beginBackgroundTask() {
        backgroundTaskID = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.endBackgroundTask()
        }
    }

    private func endBackgroundTask() {
        if backgroundTaskID != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
            backgroundTaskID = .invalid
        }
    }
    #endif

    // MARK: - Notifications

    private func setupNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func scheduleCompletionNotification(title: String, delay: TimeInterval) {
        let content = UNMutableNotificationContent()
        content.title = "Timer Complete"
        content.body = "\(title) timer has finished"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
        let request = UNNotificationRequest(identifier: "timer-complete", content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request)
    }

    private func cancelScheduledNotifications() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["timer-complete"])
    }
}

// MARK: - Managed Timer

class ManagedTimer: ObservableObject {
    let chipID: UUID
    let chipTitle: String
    let expectedDuration: TimeInterval?
    let startedAt: Date

    @Published var elapsedTime: TimeInterval = 0
    @Published var isRunning: Bool = false

    private var timer: Timer?
    private var lastTickTime: Date?

    init(chipID: UUID, chipTitle: String, expectedDuration: TimeInterval?) {
        self.chipID = chipID
        self.chipTitle = chipTitle
        self.expectedDuration = expectedDuration
        self.startedAt = Date()
    }

    func start() {
        isRunning = true
        lastTickTime = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.current.add(timer!, forMode: .common)
    }

    func pause() {
        isRunning = false
        timer?.invalidate()
        timer = nil
    }

    func resume() {
        isRunning = true
        lastTickTime = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.current.add(timer!, forMode: .common)
    }

    func stop() {
        isRunning = false
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        guard isRunning, let lastTick = lastTickTime else { return }
        let now = Date()
        elapsedTime += now.timeIntervalSince(lastTick)
        lastTickTime = now
    }

    // MARK: - Computed Properties

    var progress: Double {
        guard let expected = expectedDuration, expected > 0 else { return 0 }
        return min(elapsedTime / expected, 1.0)
    }

    var isOvertime: Bool {
        guard let expected = expectedDuration else { return false }
        return elapsedTime > expected
    }

    var formattedElapsed: String {
        formatTime(elapsedTime)
    }

    var formattedRemaining: String? {
        guard let expected = expectedDuration else { return nil }
        let remaining = expected - elapsedTime
        if remaining < 0 {
            return "+\(formatTime(abs(remaining)))"
        }
        return formatTime(remaining)
    }

    var formattedExpected: String? {
        guard let expected = expectedDuration else { return nil }
        return formatTime(expected)
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let totalSeconds = Int(abs(time))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Timer Result

struct TimerResult {
    let chipID: UUID
    let chipTitle: String
    let duration: TimeInterval
    let expectedDuration: TimeInterval?
    let completedAt: Date

    var wasCompleted: Bool {
        guard let expected = expectedDuration else { return true }
        return duration >= expected * 0.9 // Within 90% of expected
    }
}
