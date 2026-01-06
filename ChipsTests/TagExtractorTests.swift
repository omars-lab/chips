import XCTest
@testable import Chips

final class TagExtractorTests: XCTestCase {

    var extractor: TagExtractor!

    override func setUpWithError() throws {
        extractor = TagExtractor()
    }

    override func tearDownWithError() throws {
        extractor = nil
    }

    // MARK: - Hashtag Tests

    func testExtractSingleHashtag() {
        let text = "This is a #test"
        let tags = extractor.extractHashtags(from: text)

        XCTAssertEqual(tags.count, 1)
        XCTAssertEqual(tags.first, "test")
    }

    func testExtractMultipleHashtags() {
        let text = "Video #cardio #hiit #beginner"
        let tags = extractor.extractHashtags(from: text)

        XCTAssertEqual(tags.count, 3)
        XCTAssertTrue(tags.contains("cardio"))
        XCTAssertTrue(tags.contains("hiit"))
        XCTAssertTrue(tags.contains("beginner"))
    }

    func testExtractHashtagsNoMatch() {
        let text = "No hashtags here"
        let tags = extractor.extractHashtags(from: text)

        XCTAssertEqual(tags.count, 0)
    }

    func testHashtagsWithNumbers() {
        let text = "#workout2024 #30day"
        let tags = extractor.extractHashtags(from: text)

        XCTAssertEqual(tags.count, 2)
        XCTAssertTrue(tags.contains("workout2024"))
        XCTAssertTrue(tags.contains("30day"))
    }

    // MARK: - Action Tag Tests

    func testExtractTimerTag() {
        let text = "Video @timer"
        let tags = extractor.extractActionTags(from: text)

        XCTAssertEqual(tags.count, 1)
        XCTAssertEqual(tags.first?.type, .timer)
        XCTAssertNil(tags.first?.value)
    }

    func testExtractAppTag() {
        let text = "Video @app:youtube"
        let tags = extractor.extractActionTags(from: text)

        XCTAssertEqual(tags.count, 1)
        XCTAssertEqual(tags.first?.type, .app)
        XCTAssertEqual(tags.first?.value, "youtube")
    }

    func testExtractDurationTag() {
        let text = "Video @duration:30m"
        let tags = extractor.extractActionTags(from: text)

        XCTAssertEqual(tags.count, 1)
        XCTAssertEqual(tags.first?.type, .duration)
        XCTAssertEqual(tags.first?.value, "30m")
    }

    func testExtractDurationTagVariations() {
        let cases = [
            ("@duration:30s", "30s"),
            ("@duration:1h", "1h"),
            ("@duration:45m", "45m")
        ]

        for (text, expectedValue) in cases {
            let tags = extractor.extractActionTags(from: text)
            XCTAssertEqual(tags.first?.type, .duration)
            XCTAssertEqual(tags.first?.value, expectedValue)
        }
    }

    func testExtractRepeatTag() {
        let text = "Exercise @repeat:5"
        let tags = extractor.extractActionTags(from: text)

        XCTAssertEqual(tags.count, 1)
        XCTAssertEqual(tags.first?.type, .repeat)
        XCTAssertEqual(tags.first?.value, "5")
    }

    func testExtractMultipleActionTags() {
        let text = "Video @timer @app:youtube @duration:30m"
        let tags = extractor.extractActionTags(from: text)

        XCTAssertEqual(tags.count, 3)
        XCTAssertTrue(tags.contains { $0.type == .timer })
        XCTAssertTrue(tags.contains { $0.type == .app && $0.value == "youtube" })
        XCTAssertTrue(tags.contains { $0.type == .duration && $0.value == "30m" })
    }

    // MARK: - Tag Removal Tests

    func testRemoveHashtags() {
        let text = "Video #cardio #hiit"
        let result = extractor.removeHashtags(from: text)

        XCTAssertEqual(result, "Video")
    }

    func testRemoveActionTags() {
        let text = "Video @timer @app:youtube"
        let result = extractor.removeActionTags(from: text)

        XCTAssertEqual(result, "Video")
    }

    func testRemoveAllTags() {
        let text = "Video #cardio @timer @app:youtube"
        let result = extractor.removeAllTags(from: text)

        XCTAssertEqual(result, "Video")
    }

    func testRemoveTagsPreservesContent() {
        let text = "My awesome workout video #cardio has been updated @timer"
        let result = extractor.removeAllTags(from: text)

        XCTAssertEqual(result, "My awesome workout video has been updated")
    }

    // MARK: - Edge Cases

    func testEmptyString() {
        let text = ""

        XCTAssertEqual(extractor.extractHashtags(from: text).count, 0)
        XCTAssertEqual(extractor.extractActionTags(from: text).count, 0)
        XCTAssertEqual(extractor.removeAllTags(from: text), "")
    }

    func testNoTags() {
        let text = "Just a regular string"

        XCTAssertEqual(extractor.extractHashtags(from: text).count, 0)
        XCTAssertEqual(extractor.extractActionTags(from: text).count, 0)
        XCTAssertEqual(extractor.removeAllTags(from: text), "Just a regular string")
    }

    func testTagAtStartOfString() {
        let text = "#cardio workout"
        let tags = extractor.extractHashtags(from: text)

        XCTAssertEqual(tags.first, "cardio")
    }

    func testTagAtEndOfString() {
        let text = "workout #cardio"
        let tags = extractor.extractHashtags(from: text)

        XCTAssertEqual(tags.first, "cardio")
    }

    // MARK: - Array Extension Tests

    func testContainsType() {
        let tags = [
            TagExtractor.ActionTag(type: .timer, value: nil, rawMatch: "@timer"),
            TagExtractor.ActionTag(type: .app, value: "youtube", rawMatch: "@app:youtube")
        ]

        XCTAssertTrue(tags.contains(type: .timer))
        XCTAssertTrue(tags.contains(type: .app))
        XCTAssertFalse(tags.contains(type: .duration))
    }

    func testFirstOfType() {
        let tags = [
            TagExtractor.ActionTag(type: .timer, value: nil, rawMatch: "@timer"),
            TagExtractor.ActionTag(type: .app, value: "youtube", rawMatch: "@app:youtube")
        ]

        XCTAssertNotNil(tags.first(ofType: .timer))
        XCTAssertEqual(tags.first(ofType: .app)?.value, "youtube")
        XCTAssertNil(tags.first(ofType: .duration))
    }
}
