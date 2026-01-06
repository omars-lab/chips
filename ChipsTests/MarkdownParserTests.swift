import XCTest
@testable import Chips

final class MarkdownParserTests: XCTestCase {

    var parser: MarkdownParser!

    override func setUpWithError() throws {
        parser = MarkdownParser()
    }

    override func tearDownWithError() throws {
        parser = nil
    }

    // MARK: - Basic Parsing Tests

    func testParseSimpleList() throws {
        let markdown = """
        # My List

        - Item 1
        - Item 2
        - Item 3
        """

        let result = parser.parse(markdown)

        XCTAssertEqual(result.chips.count, 3)
        XCTAssertEqual(result.chips[0].title, "Item 1")
        XCTAssertEqual(result.chips[1].title, "Item 2")
        XCTAssertEqual(result.chips[2].title, "Item 3")
    }

    func testParseWithLinks() throws {
        let markdown = """
        - [Video 1](https://youtube.com/watch?v=abc)
        - [Video 2](https://youtube.com/watch?v=def)
        """

        let result = parser.parse(markdown)

        XCTAssertEqual(result.chips.count, 2)
        XCTAssertEqual(result.chips[0].title, "Video 1")
        XCTAssertEqual(result.chips[0].url?.absoluteString, "https://youtube.com/watch?v=abc")
        XCTAssertEqual(result.chips[0].actionType, "url")
    }

    func testParseSections() throws {
        let markdown = """
        # Section 1

        - Item A

        ## Section 2

        - Item B
        - Item C
        """

        let result = parser.parse(markdown)

        XCTAssertEqual(result.chips.count, 3)
        XCTAssertEqual(result.chips[0].sectionTitle, "Section 1")
        XCTAssertEqual(result.chips[1].sectionTitle, "Section 2")
        XCTAssertEqual(result.chips[2].sectionTitle, "Section 2")
    }

    // MARK: - Tag Extraction Tests

    func testParseHashtags() throws {
        let markdown = """
        - Workout video #cardio #hiit
        """

        let result = parser.parse(markdown)

        XCTAssertEqual(result.chips.count, 1)
        XCTAssertEqual(result.chips[0].tags.count, 2)
        XCTAssertTrue(result.chips[0].tags.contains("cardio"))
        XCTAssertTrue(result.chips[0].tags.contains("hiit"))
        // Title should have tags removed
        XCTAssertEqual(result.chips[0].title, "Workout video")
    }

    func testParseActionTags() throws {
        let markdown = """
        - [HIIT Workout](https://youtube.com/watch?v=abc) @timer @app:youtube
        """

        let result = parser.parse(markdown)

        XCTAssertEqual(result.chips.count, 1)
        XCTAssertEqual(result.chips[0].actionTags.count, 2)
        XCTAssertTrue(result.chips[0].actionTags.contains { $0.type == .timer })
        XCTAssertTrue(result.chips[0].actionTags.contains { $0.type == .app && $0.value == "youtube" })
    }

    func testParseDurationTag() throws {
        let markdown = """
        - Video @duration:30m
        """

        let result = parser.parse(markdown)

        XCTAssertEqual(result.chips.count, 1)

        let durationTag = result.chips[0].actionTags.first { $0.type == .duration }
        XCTAssertNotNil(durationTag)
        XCTAssertEqual(durationTag?.value, "30m")
    }

    func testParseRepeatTag() throws {
        let markdown = """
        - Repeat exercise @repeat:5
        """

        let result = parser.parse(markdown)

        let repeatTag = result.chips[0].actionTags.first { $0.type == .repeat }
        XCTAssertNotNil(repeatTag)
        XCTAssertEqual(repeatTag?.value, "5")
    }

    // MARK: - Task List Tests

    func testParseTaskList() throws {
        let markdown = """
        - [ ] Uncompleted task
        - [x] Completed task
        - [X] Also completed
        """

        let result = parser.parse(markdown)

        XCTAssertEqual(result.chips.count, 3)
        XCTAssertTrue(result.chips[0].isTaskItem)
        XCTAssertFalse(result.chips[0].isCompleted)
        XCTAssertTrue(result.chips[1].isTaskItem)
        XCTAssertTrue(result.chips[1].isCompleted)
        XCTAssertTrue(result.chips[2].isTaskItem)
        XCTAssertTrue(result.chips[2].isCompleted)
    }

    // MARK: - Frontmatter Tests

    func testParseFrontmatter() throws {
        let markdown = """
        ---
        title: My Workouts
        category: fitness
        default_action: url
        default_app: youtube
        ---

        - Workout 1
        """

        let result = parser.parse(markdown)

        XCTAssertNotNil(result.frontmatter)
        XCTAssertEqual(result.frontmatter?.title, "My Workouts")
        XCTAssertEqual(result.frontmatter?.category, "fitness")
        XCTAssertEqual(result.frontmatter?.defaultAction, "url")
        XCTAssertEqual(result.frontmatter?.defaultApp, "youtube")
    }

    func testParseWithoutFrontmatter() throws {
        let markdown = """
        # Just a heading

        - Item 1
        """

        let result = parser.parse(markdown)

        XCTAssertNil(result.frontmatter)
        XCTAssertEqual(result.chips.count, 1)
    }

    // MARK: - Sort Order Tests

    func testSortOrder() throws {
        let markdown = """
        - First
        - Second
        - Third
        """

        let result = parser.parse(markdown)

        XCTAssertEqual(result.chips[0].sortOrder, 0)
        XCTAssertEqual(result.chips[1].sortOrder, 1)
        XCTAssertEqual(result.chips[2].sortOrder, 2)
    }

    // MARK: - Action Payload Tests

    func testActionPayloadGeneration() throws {
        let markdown = """
        - [Video](https://youtube.com/watch?v=abc) @app:youtube @duration:30m
        """

        let result = parser.parse(markdown)
        let chip = result.chips[0]

        XCTAssertEqual(chip.actionType, "app")

        // Parse the JSON payload
        guard let data = chip.actionPayload.data(using: .utf8),
              let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            XCTFail("Failed to parse action payload")
            return
        }

        XCTAssertEqual(payload["url"] as? String, "https://youtube.com/watch?v=abc")
        XCTAssertEqual(payload["preferredApp"] as? String, "youtube")
        XCTAssertEqual(payload["expectedDuration"] as? Int, 1800) // 30 minutes in seconds
    }

    // MARK: - Edge Cases

    func testEmptyMarkdown() throws {
        let result = parser.parse("")
        XCTAssertEqual(result.chips.count, 0)
        XCTAssertNil(result.frontmatter)
    }

    func testMarkdownWithOnlyHeadings() throws {
        let markdown = """
        # Heading 1
        ## Heading 2
        ### Heading 3
        """

        let result = parser.parse(markdown)
        XCTAssertEqual(result.chips.count, 0)
    }

    func testOrderedList() throws {
        let markdown = """
        1. First item
        2. Second item
        3. Third item
        """

        let result = parser.parse(markdown)

        XCTAssertEqual(result.chips.count, 3)
        XCTAssertEqual(result.chips[0].title, "First item")
    }

    // MARK: - Complex Document Test

    func testComplexDocument() throws {
        let markdown = MarkdownParser.sample

        let result = parser.parse(markdown)

        // Should have frontmatter
        XCTAssertNotNil(result.frontmatter)
        XCTAssertEqual(result.frontmatter?.title, "Treadmill Workouts")

        // Should have multiple chips
        XCTAssertGreaterThan(result.chips.count, 0)

        // First chip should have proper data
        let firstChip = result.chips[0]
        XCTAssertEqual(firstChip.title, "30 Min HIIT Workout")
        XCTAssertTrue(firstChip.tags.contains("cardio"))
        XCTAssertTrue(firstChip.actionTags.contains { $0.type == .timer })
    }
}
