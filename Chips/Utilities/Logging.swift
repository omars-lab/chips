import Foundation
import os.log

/// Centralized logging utility
enum AppLogger {
    /// Log an info message with optional category
    static func info(_ message: String, category: String = AppConstants.LoggerCategory.app) {
        let logger = Logger(subsystem: AppConstants.loggerSubsystem, category: category)
        logger.info("\(message, privacy: .public)")
        print("[\(category)] \(message)")
        fflush(stdout)
    }
    
    /// Log a debug message
    static func debug(_ message: String, category: String = AppConstants.LoggerCategory.app) {
        let logger = Logger(subsystem: AppConstants.loggerSubsystem, category: category)
        logger.debug("\(message, privacy: .public)")
        print("[\(category)] \(message)")
        fflush(stdout)
    }
    
    /// Log a warning message
    static func warning(_ message: String, category: String = AppConstants.LoggerCategory.app) {
        let logger = Logger(subsystem: AppConstants.loggerSubsystem, category: category)
        logger.warning("\(message, privacy: .public)")
        print("⚠️ [\(category)] \(message)")
        fflush(stdout)
    }
    
    /// Log an error message
    static func error(_ message: String, category: String = AppConstants.LoggerCategory.app) {
        let logger = Logger(subsystem: AppConstants.loggerSubsystem, category: category)
        logger.error("\(message, privacy: .public)")
        print("❌ [\(category)] \(message)")
        fflush(stdout)
    }
}

