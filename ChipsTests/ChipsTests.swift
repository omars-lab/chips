import XCTest
@testable import Chips

final class ChipsTests: XCTestCase {

    var persistenceController: PersistenceController!

    override func setUpWithError() throws {
        persistenceController = PersistenceController(inMemory: true)
    }

    override func tearDownWithError() throws {
        persistenceController = nil
    }

    // MARK: - ChipSource Tests

    func testCreateChipSource() throws {
        let context = persistenceController.container.viewContext

        let source = ChipSource(context: context)
        source.id = UUID()
        source.name = "Test Workouts"
        source.iCloudPath = "/test/workouts.md"
        source.lastParsed = Date()
        source.checksum = "abc123"

        try context.save()

        let fetchRequest = ChipSource.fetchRequest()
        let sources = try context.fetch(fetchRequest)

        XCTAssertEqual(sources.count, 1)
        XCTAssertEqual(sources.first?.name, "Test Workouts")
    }

    // MARK: - Chip Tests

    func testCreateChip() throws {
        let context = persistenceController.container.viewContext

        let source = ChipSource(context: context)
        source.id = UUID()
        source.name = "Test Source"

        let chip = Chip(context: context)
        chip.id = UUID()
        chip.title = "Test Chip"
        chip.actionType = "url"
        chip.actionPayload = "{\"url\": \"https://example.com\"}"
        chip.source = source
        chip.createdAt = Date()

        try context.save()

        let fetchRequest = Chip.fetchRequest()
        let chips = try context.fetch(fetchRequest)

        XCTAssertEqual(chips.count, 1)
        XCTAssertEqual(chips.first?.title, "Test Chip")
        XCTAssertEqual(chips.first?.source?.name, "Test Source")
    }

    func testChipCompletion() throws {
        let context = persistenceController.container.viewContext

        let chip = Chip(context: context)
        chip.id = UUID()
        chip.title = "Test Chip"
        chip.isCompleted = false

        XCTAssertFalse(chip.isCompleted)
        XCTAssertNil(chip.completedAt)

        chip.isCompleted = true
        chip.completedAt = Date()

        XCTAssertTrue(chip.isCompleted)
        XCTAssertNotNil(chip.completedAt)
    }

    func testChipActionData() throws {
        let context = persistenceController.container.viewContext

        let chip = Chip(context: context)
        chip.id = UUID()
        chip.title = "Test Chip"
        chip.actionType = "url"
        chip.actionPayload = "{\"url\": \"https://youtube.com/watch?v=abc123\", \"preferredApp\": \"youtube\"}"

        let actionData = chip.actionData

        XCTAssertNotNil(actionData)
        XCTAssertEqual(actionData?.url, "https://youtube.com/watch?v=abc123")
        XCTAssertEqual(actionData?.preferredApp, "youtube")
    }

    func testChipMetadata() throws {
        let context = persistenceController.container.viewContext

        let chip = Chip(context: context)
        chip.id = UUID()
        chip.title = "Test Chip"
        chip.metadata = "{\"tags\": [\"cardio\", \"hiit\"], \"duration\": \"30m\"}"

        let metadata = chip.chipMetadata

        XCTAssertNotNil(metadata)
        XCTAssertEqual(metadata?.tags?.count, 2)
        XCTAssertEqual(metadata?.duration, "30m")
    }

    // MARK: - ChipInteraction Tests

    func testCreateInteraction() throws {
        let context = persistenceController.container.viewContext

        let chip = Chip(context: context)
        chip.id = UUID()
        chip.title = "Test Chip"

        let interaction = ChipInteraction(context: context)
        interaction.id = UUID()
        interaction.chip = chip
        interaction.timestamp = Date()
        interaction.actionTaken = "opened_url"
        interaction.deviceName = "Test Device"

        try context.save()

        XCTAssertEqual(chip.interactionCount, 1)
        XCTAssertEqual(chip.interactionsArray.first?.actionTaken, "opened_url")
    }

    func testInteractionDurationFormatting() throws {
        let context = persistenceController.container.viewContext

        let interaction = ChipInteraction(context: context)
        interaction.id = UUID()
        interaction.duration = 125 // 2 minutes 5 seconds

        XCTAssertEqual(interaction.formattedDuration, "2m 5s")

        interaction.duration = 45 // 45 seconds
        XCTAssertEqual(interaction.formattedDuration, "45s")

        interaction.duration = 0
        XCTAssertNil(interaction.formattedDuration)
    }

    // MARK: - Relationship Tests

    func testSourceChipRelationship() throws {
        let context = persistenceController.container.viewContext

        let source = ChipSource(context: context)
        source.id = UUID()
        source.name = "Test Source"

        let chip1 = Chip(context: context)
        chip1.id = UUID()
        chip1.title = "Chip 1"
        chip1.sortOrder = 0
        chip1.source = source

        let chip2 = Chip(context: context)
        chip2.id = UUID()
        chip2.title = "Chip 2"
        chip2.sortOrder = 1
        chip2.source = source

        try context.save()

        XCTAssertEqual(source.chipsArray.count, 2)
        XCTAssertEqual(source.chipsArray[0].title, "Chip 1")
        XCTAssertEqual(source.chipsArray[1].title, "Chip 2")
    }

    // MARK: - Performance Tests

    func testBulkChipCreation() throws {
        let context = persistenceController.container.viewContext

        measure {
            for i in 0..<100 {
                let chip = Chip(context: context)
                chip.id = UUID()
                chip.title = "Chip \(i)"
                chip.sortOrder = Int32(i)
            }
            try? context.save()
        }
    }
}
