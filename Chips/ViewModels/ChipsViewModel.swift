import Foundation
import SwiftUI
import CoreData
import Combine

/// ViewModel for the Chips tab
@MainActor
final class ChipsViewModel: ObservableObject {
    @Published var selectedSourceID: UUID?
    @Published var searchText = ""
    @Published var showCompleted = true
    @Published var selectedTags: Set<String> = []
    @Published var isLoading = false
    @Published var error: Error?

    private var cancellables = Set<AnyCancellable>()

    init() {
        // Set up search debouncing
        $searchText
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    /// Execute the primary action for a chip
    func executeAction(for chip: Chip, in context: NSManagedObjectContext) {
        // Create interaction record
        let interaction = ChipInteraction(context: context)
        interaction.id = UUID()
        interaction.chip = chip
        interaction.timestamp = Date()
        interaction.actionTaken = "opened_\(chip.actionType ?? "unknown")"
        interaction.deviceName = Self.deviceName

        // Execute the action
        if let urlString = chip.actionData?.url,
           let url = URL(string: urlString) {
            openURL(url, preferredApp: chip.actionData?.preferredApp)
        }

        // Save
        do {
            try context.save()
        } catch {
            self.error = error
        }
    }

    /// Toggle completion status of a chip
    func toggleCompleted(for chip: Chip, in context: NSManagedObjectContext) {
        chip.isCompleted.toggle()
        chip.completedAt = chip.isCompleted ? Date() : nil

        if chip.isCompleted {
            let interaction = ChipInteraction(context: context)
            interaction.id = UUID()
            interaction.chip = chip
            interaction.timestamp = Date()
            interaction.actionTaken = "completed"
            interaction.deviceName = Self.deviceName
        }

        do {
            try context.save()
        } catch {
            self.error = error
        }
    }

    /// Open a URL, optionally in a specific app
    private func openURL(_ url: URL, preferredApp: String?) {
        #if os(iOS)
        if let app = preferredApp {
            var appURL: URL?
            switch app.lowercased() {
            case "youtube":
                if let videoID = extractYouTubeID(from: url) {
                    appURL = URL(string: "youtube://watch?v=\(videoID)")
                }
            default:
                break
            }

            if let appURL = appURL {
                UIApplication.shared.open(appURL) { success in
                    if !success {
                        UIApplication.shared.open(url)
                    }
                }
                return
            }
        }
        UIApplication.shared.open(url)
        #elseif os(macOS)
        NSWorkspace.shared.open(url)
        #endif
    }

    private func extractYouTubeID(from url: URL) -> String? {
        if let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
           let videoID = queryItems.first(where: { $0.name == "v" })?.value {
            return videoID
        }
        return nil
    }

    static var deviceName: String {
        #if os(iOS)
        return UIDevice.current.name
        #elseif os(macOS)
        return Host.current().localizedName ?? "Mac"
        #endif
    }
}
