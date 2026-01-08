import Foundation

/// Service for fetching and summarizing content from URLs
@MainActor
final class URLSummarizer {
    static let shared = URLSummarizer()
    
    private let textSummarizer = TextSummarizer.shared
    
    private init() {}
    
    /// Fetch content from URL and generate a summary
    /// - Parameters:
    ///   - url: The URL to fetch content from
    ///   - description: Optional text description of the link
    /// - Returns: A summary string, or nil if summarization fails
    func summarizeURL(_ url: URL, description: String? = nil) async -> String? {
        AppLogger.info("📄 Summarizing URL: \(url.absoluteString)", category: AppConstants.LoggerCategory.urlSummarizer)
        
        // If we have a description, use that for summarization
        if let description = description, !description.isEmpty {
            AppLogger.info("Using provided description for summarization", category: AppConstants.LoggerCategory.urlSummarizer)
            return await textSummarizer.summarize(description)
        }
        
        // Try to fetch metadata first (Open Graph tags, title, description)
        let metadataFetcher = URLMetadataFetcher.shared
        if let metadata = await metadataFetcher.fetchMetadata(from: url) {
            // Use Open Graph description or meta description if available
            if let metaDescription = metadata.description, !metaDescription.isEmpty {
                AppLogger.info("Using metadata description for summarization", category: AppConstants.LoggerCategory.urlSummarizer)
                return await textSummarizer.summarize(metaDescription)
            }
            
            // If we have a title but no description, use title as context
            if let title = metadata.title, !title.isEmpty {
                AppLogger.info("Using metadata title as description", category: AppConstants.LoggerCategory.urlSummarizer)
                return await textSummarizer.summarize(title)
            }
        }
        
        // Fallback: fetch full content and extract text
        guard let content = await fetchTextContent(from: url) else {
            AppLogger.warning("Failed to fetch content from URL", category: AppConstants.LoggerCategory.urlSummarizer)
            return nil
        }
        
        return await textSummarizer.summarize(content)
    }
    
    /// Fetch text content from a URL
    private func fetchTextContent(from url: URL) async -> String? {
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                AppLogger.warning("Invalid HTTP response", category: AppConstants.LoggerCategory.urlSummarizer)
                return nil
            }
            
            // Check content type
            let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type") ?? ""
            
            if contentType.contains("text/html") {
                // Extract text from HTML
                // In production, use a proper HTML parser like SwiftSoup
                if let htmlString = String(data: data, encoding: .utf8) {
                    return extractTextFromHTML(htmlString)
                }
            } else if contentType.contains("text/plain") {
                return String(data: data, encoding: .utf8)
            }
            
            return nil
        } catch {
            AppLogger.error("Error fetching URL: \(error.localizedDescription)", category: AppConstants.LoggerCategory.urlSummarizer)
            return nil
        }
    }
    
    /// Extract text content from HTML (simplified)
    /// In production, use SwiftSoup or similar library
    private func extractTextFromHTML(_ html: String) -> String {
        // Very basic HTML tag removal
        // For production, use a proper HTML parser
        var text = html
        
        // Remove script and style tags
        text = text.replacingOccurrences(
            of: #"<script[^>]*>.*?</script>"#,
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )
        text = text.replacingOccurrences(
            of: #"<style[^>]*>.*?</style>"#,
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )
        
        // Remove HTML tags
        text = text.replacingOccurrences(
            of: #"<[^>]+>"#,
            with: " ",
            options: .regularExpression
        )
        
        // Decode HTML entities (basic)
        text = text.replacingOccurrences(of: "&nbsp;", with: " ")
        text = text.replacingOccurrences(of: "&amp;", with: "&")
        text = text.replacingOccurrences(of: "&lt;", with: "<")
        text = text.replacingOccurrences(of: "&gt;", with: ">")
        text = text.replacingOccurrences(of: "&quot;", with: "\"")
        
        // Clean up whitespace
        text = text.replacingOccurrences(
            of: #"\s+"#,
            with: " ",
            options: .regularExpression
        )
        
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

