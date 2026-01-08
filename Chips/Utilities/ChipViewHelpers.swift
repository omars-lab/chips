import Foundation
import SwiftUI

/// Shared helper functions and computed properties for chip views
enum ChipViewHelpers {
    
    // MARK: - Action Icon
    
    /// Get the appropriate icon for a chip based on its action type
    static func actionIcon(for chip: Chip) -> some View {
        Group {
            switch chip.actionType {
            case "url":
                // Check if this is a YouTube URL (from actionData, chip metadata, or title)
                let isYouTube = chip.actionData?.preferredApp == "youtube" || 
                               chip.actionData?.url?.contains("youtube.com") == true ||
                               chip.actionData?.url?.contains("youtu.be") == true ||
                               chip.chipMetadata?.metadataSiteName?.lowercased() == "youtube" ||
                               chip.unwrappedTitle.contains("youtube.com") ||
                               chip.unwrappedTitle.contains("youtu.be")
                
                if isYouTube {
                    Image(systemName: "play.rectangle.fill")
                        .foregroundStyle(.red)
                } else {
                    Image(systemName: "link")
                        .foregroundStyle(.blue)
                }
            case "timer":
                Image(systemName: "timer")
                    .foregroundStyle(.orange)
            case "app":
                Image(systemName: "app")
                    .foregroundStyle(.purple)
            default:
                Image(systemName: "square")
                    .foregroundStyle(.gray)
            }
        }
    }
    
    /// Get the background color for action icons
    static func iconBackgroundColor(for chip: Chip) -> Color {
        switch chip.actionType {
        case "url":
            return chip.actionData?.preferredApp == "youtube" ? .red : .blue
        case "timer":
            return .orange
        case "app":
            return .purple
        default:
            return .gray
        }
    }
    
    // MARK: - Duration Formatting
    
    /// Format a duration in seconds to a human-readable string
    /// - Parameter seconds: Duration in seconds
    /// - Returns: Formatted string like "30m" or "1h 15m"
    static func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        if minutes >= 60 {
            let hours = minutes / 60
            let mins = minutes % 60
            return "\(hours)h\(mins > 0 ? " \(mins)m" : "")"
        }
        return "\(minutes)m"
    }
    
    // MARK: - Completion Toggle
    
    /// Toggle completion status of a chip and log interaction
    /// - Parameters:
    ///   - chip: The chip to toggle
    ///   - context: Core Data context for saving
    ///   - timerManager: Timer manager to stop timer if needed
    ///   - isActiveTimer: Whether this chip has an active timer
    @MainActor
    static func toggleCompleted(
        for chip: Chip,
        in context: NSManagedObjectContext,
        timerManager: TimerManager,
        isActiveTimer: Bool
    ) {
        withAnimation {
            chip.isCompleted.toggle()
            chip.completedAt = chip.isCompleted ? Date() : nil

            if chip.isCompleted {
                // Log completion interaction
                let interaction = ChipInteraction(context: context)
                interaction.id = UUID()
                interaction.chip = chip
                interaction.timestamp = Date()
                interaction.actionTaken = "completed"
                interaction.deviceName = ActionEngine.deviceName

                // Stop timer if this chip has active timer
                if isActiveTimer {
                    _ = timerManager.stopTimer()
                }
            }

            try? context.save()
        }
    }
}

