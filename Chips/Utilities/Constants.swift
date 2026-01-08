import Foundation

/// App-wide constants
enum AppConstants {
    static let bundleID = "com.chips.app"
    static let cloudKitContainer = "iCloud.com.chips.app"
    static let loggerSubsystem = "com.chips.app"
    
    // Logger categories
    enum LoggerCategory {
        static let app = "App"
        static let actionEngine = "ActionEngine"
        static let chipRowView = "ChipRowView"
        static let urlMetadataFetcher = "URLMetadataFetcher"
        static let chipSummaryService = "ChipSummaryService"
        static let urlSummarizer = "URLSummarizer"
    }
}

