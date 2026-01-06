import CoreData
import CloudKit

/// Manages Core Data stack with CloudKit synchronization
final class PersistenceController: ObservableObject {
    static let shared = PersistenceController()

    /// Preview instance for SwiftUI previews
    static var preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        let viewContext = controller.container.viewContext

        // Create sample data for previews
        let source = ChipSource(context: viewContext)
        source.id = UUID()
        source.name = "Sample Workouts"
        source.iCloudPath = "/Workouts/treadmill.md"
        source.lastParsed = Date()
        source.checksum = "abc123"

        let chip = Chip(context: viewContext)
        chip.id = UUID()
        chip.source = source
        chip.title = "30 Min HIIT Workout"
        chip.rawMarkdown = "- [30 Min HIIT](https://youtube.com/watch?v=xxx) @timer"
        chip.actionType = "url"
        chip.actionPayload = "{\"url\": \"https://youtube.com/watch?v=xxx\"}"
        chip.metadata = "{\"tags\": [\"cardio\", \"hiit\"]}"
        chip.sortOrder = 0
        chip.isCompleted = false
        chip.createdAt = Date()

        let interaction = ChipInteraction(context: viewContext)
        interaction.id = UUID()
        interaction.chip = chip
        interaction.timestamp = Date()
        interaction.actionTaken = "opened_url"
        interaction.deviceName = "iPhone"

        do {
            try viewContext.save()
        } catch {
            fatalError("Failed to save preview context: \(error)")
        }

        return controller
    }()

    /// The CloudKit-enabled persistent container
    let container: NSPersistentCloudKitContainer

    /// The main view context
    var viewContext: NSManagedObjectContext {
        container.viewContext
    }

    /// Initialize the persistence controller
    /// - Parameter inMemory: If true, uses an in-memory store (for previews/testing)
    init(inMemory: Bool = false) {
        // Use programmatic model
        let model = CoreDataModel.createModel()
        container = NSPersistentCloudKitContainer(name: "Chips", managedObjectModel: model)

        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        } else {
            // Configure CloudKit container
            guard let description = container.persistentStoreDescriptions.first else {
                fatalError("Failed to retrieve persistent store description")
            }

            #if os(iOS)
            // Set CloudKit container identifier (iOS only for now)
            description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
                containerIdentifier: "iCloud.com.chips.app"
            )

            // Enable persistent history tracking for CloudKit sync
            description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
            #else
            // macOS: Use local storage only (CloudKit requires proper signing/entitlements)
            // Enable persistent history tracking for local sync
            description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            #endif
        }

        container.loadPersistentStores { storeDescription, error in
            if let error = error as NSError? {
                // Log error but don't crash - allow app to run with local storage
                print("⚠️ Failed to load persistent stores: \(error), \(error.userInfo)")
                print("   Continuing with local storage only...")
                // Don't fatalError - allow app to continue
            }
        }

        // Configure view context
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        // Enable query generations for consistent reads
        try? container.viewContext.setQueryGenerationFrom(.current)
    }

    // MARK: - Convenience Methods

    /// Save the view context if there are changes
    func save() {
        let context = container.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                print("Failed to save context: \(error)")
            }
        }
    }

    /// Create a new background context for bulk operations
    func newBackgroundContext() -> NSManagedObjectContext {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return context
    }
}
