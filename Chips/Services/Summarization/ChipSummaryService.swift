import Foundation
import CoreData

/// Service for managing chip summaries
@MainActor
final class ChipSummaryService {
    static let shared = ChipSummaryService()
    
    private let urlSummarizer = URLSummarizer.shared
    
    private init() {}
    
    /// Generate and store summary for a chip
    /// - Parameters:
    ///   - chip: The chip to summarize
    ///   - description: Optional text description of the link
    ///   - context: Core Data context for saving
    func generateSummary(
        for chip: Chip,
        description: String? = nil,
        in context: NSManagedObjectContext
    ) async {
        AppLogger.info("📝 Generating summary for chip: \(chip.unwrappedTitle)", category: AppConstants.LoggerCategory.chipSummaryService)
        
        // Get URL from chip
        let urlString = chip.actionData?.url ?? chip.unwrappedTitle.extractURL()
        
        guard let urlString = urlString else {
            AppLogger.warning("No URL found for chip", category: AppConstants.LoggerCategory.chipSummaryService)
            return
        }
        
        guard let url = URL(string: urlString) else {
            AppLogger.warning("Invalid URL: \(urlString)", category: AppConstants.LoggerCategory.chipSummaryService)
            return
        }
        
        // Try to fetch metadata first to get description if none provided
        var descriptionToUse = description
        if descriptionToUse == nil || descriptionToUse?.isEmpty == true {
            let metadataFetcher = URLMetadataFetcher.shared
            if let metadata = await metadataFetcher.fetchMetadata(from: url) {
                // Prefer Open Graph description, then meta description, then title
                descriptionToUse = metadata.description ?? metadata.title
            }
        }
        
        // Generate summary
        guard let summary = await urlSummarizer.summarizeURL(url, description: descriptionToUse) else {
            AppLogger.warning("Failed to generate summary", category: AppConstants.LoggerCategory.chipSummaryService)
            return
        }
        
        // Store summary in metadata
        await storeSummary(summary, for: chip, in: context)
    }
    
    /// Get summary for a chip (from metadata)
    func getSummary(for chip: Chip) -> String? {
        // Try to extract from ChipMetadata struct
        if let metadata = chip.chipMetadata,
           let summary = metadata.summary {
            return summary
        }
        
        // Fallback: check if stored in custom metadata JSON (legacy format)
        if let metadataString = chip.metadata,
           let data = metadataString.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let summary = json["summary"] as? String {
            return summary
        }
        
        return nil
    }
    
    /// Store summary in chip metadata
    private func storeSummary(
        _ summary: String,
        for chip: Chip,
        in context: NSManagedObjectContext
    ) async {
        // Get existing chip metadata or create new
        var chipMeta = chip.chipMetadata ?? ChipMetadata()
        
        // Store summary and timestamp
        chipMeta.summary = summary
        chipMeta.summaryGeneratedAt = ISO8601DateFormatter().string(from: Date())
        
        // Save back to chip
        chip.chipMetadata = chipMeta
        
        do {
            try context.save()
            AppLogger.info("✅ Summary saved for chip", category: AppConstants.LoggerCategory.chipSummaryService)
        } catch {
            AppLogger.error("Failed to save summary: \(error.localizedDescription)", category: AppConstants.LoggerCategory.chipSummaryService)
        }
    }
    
    /// Extract URL from title if it's a URL
}

