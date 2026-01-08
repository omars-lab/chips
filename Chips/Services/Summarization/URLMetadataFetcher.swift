import Foundation

/// Fetches metadata from URLs (Open Graph tags, title, description, etc.)
/// Similar to what curl or a web scraper would extract
@MainActor
final class URLMetadataFetcher {
    static let shared = URLMetadataFetcher()
    
    private init() {}
    
    /// Metadata extracted from a URL
    struct URLMetadata {
        let title: String?
        let description: String?
        let imageURL: String?
        let siteName: String?
        let type: String?
        let rawHTML: String?
    }
    
    /// Fetch metadata from a URL
    /// - Parameter url: The URL to fetch metadata from
    /// - Returns: URLMetadata with extracted information, or nil if fetch fails
    func fetchMetadata(from url: URL) async -> URLMetadata? {
        AppLogger.info("📡 Fetching metadata from URL: \(url.absoluteString)", category: AppConstants.LoggerCategory.urlMetadataFetcher)
        
        // Check if this is a YouTube URL - use oEmbed API for better metadata
        if let youtubeMetadata = await fetchYouTubeMetadata(from: url) {
            AppLogger.info("✅ Fetched YouTube metadata via oEmbed API", category: AppConstants.LoggerCategory.urlMetadataFetcher)
            return youtubeMetadata
        }
        
        // Fallback to HTML parsing for other URLs
        do {
            var request = URLRequest(url: url)
            request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
            request.timeoutInterval = 10.0
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                AppLogger.warning("Invalid HTTP response: \(response)", category: AppConstants.LoggerCategory.urlMetadataFetcher)
                return nil
            }
            
            // Check content type
            let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type") ?? ""
            
            guard contentType.contains("text/html") else {
                AppLogger.info("Content type is not HTML: \(contentType)", category: AppConstants.LoggerCategory.urlMetadataFetcher)
                return nil
            }
            
            guard let htmlString = String(data: data, encoding: .utf8) else {
                AppLogger.warning("Failed to decode HTML", category: AppConstants.LoggerCategory.urlMetadataFetcher)
                return nil
            }
            
            return extractMetadata(from: htmlString, url: url)
            
        } catch {
            AppLogger.error("Error fetching URL metadata: \(error.localizedDescription)", category: AppConstants.LoggerCategory.urlMetadataFetcher)
            return nil
        }
    }
    
    /// Fetch YouTube metadata using oEmbed API
    /// Documentation: https://oembed.com/providers.json
    /// Example: http://www.youtube.com/oembed?url=http%3A//youtube.com/watch%3Fv%3DM3r2XDceM6A&format=json
    private func fetchYouTubeMetadata(from url: URL) async -> URLMetadata? {
        // Check if this is a YouTube URL
        guard let host = url.host?.lowercased(),
              (host.contains("youtube.com") || host == "youtu.be") else {
            return nil
        }
        
        // Build oEmbed URL
        guard let encodedURL = url.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let oembedURL = URL(string: "https://www.youtube.com/oembed?url=\(encodedURL)&format=json") else {
            AppLogger.warning("Failed to build YouTube oEmbed URL", category: AppConstants.LoggerCategory.urlMetadataFetcher)
            return nil
        }
        
        AppLogger.info("📡 Fetching YouTube oEmbed metadata: \(oembedURL.absoluteString)", category: AppConstants.LoggerCategory.urlMetadataFetcher)
        
        do {
            var request = URLRequest(url: oembedURL)
            request.timeoutInterval = 10.0
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                AppLogger.warning("YouTube oEmbed API returned invalid response: \(response)", category: AppConstants.LoggerCategory.urlMetadataFetcher)
                return nil
            }
            
            // Parse JSON response
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                AppLogger.warning("Failed to parse YouTube oEmbed JSON", category: AppConstants.LoggerCategory.urlMetadataFetcher)
                return nil
            }
            
            // Extract metadata from oEmbed response
            // oEmbed format: https://oembed.com/
            // Response includes: title, author_name, author_url, thumbnail_url, html, etc.
            let title = json["title"] as? String
            let authorName = json["author_name"] as? String
            let thumbnailURL = json["thumbnail_url"] as? String
            let html = json["html"] as? String
            let providerName = json["provider_name"] as? String
            
            // Build description from available fields
            // For YouTube, we can use author_name as context
            var description: String?
            if let author = authorName {
                description = "Video by \(author)"
            }
            
            AppLogger.info("✅ YouTube oEmbed - Title: \(title ?? "none"), Author: \(authorName ?? "none"), Thumbnail: \(thumbnailURL != nil ? "yes" : "no")", category: AppConstants.LoggerCategory.urlMetadataFetcher)
            
            return URLMetadata(
                title: title,
                description: description,
                imageURL: thumbnailURL,
                siteName: providerName ?? "YouTube",
                type: "video",
                rawHTML: html
            )
            
        } catch {
            AppLogger.error("Error fetching YouTube oEmbed metadata: \(error.localizedDescription)", category: AppConstants.LoggerCategory.urlMetadataFetcher)
            return nil
        }
    }
    
    /// Extract metadata from HTML string
    private func extractMetadata(from html: String, url: URL) -> URLMetadata {
        var title: String?
        var description: String?
        var imageURL: String?
        var siteName: String?
        var type: String?
        
        // Extract Open Graph tags
        title = extractOpenGraphTag(html: html, property: "og:title") ?? extractHTMLTag(html: html, tag: "title")
        description = extractOpenGraphTag(html: html, property: "og:description") ?? extractMetaTag(html: html, name: "description")
        imageURL = extractOpenGraphTag(html: html, property: "og:image")
        siteName = extractOpenGraphTag(html: html, property: "og:site_name")
        type = extractOpenGraphTag(html: html, property: "og:type")
        
        // Resolve relative image URLs
        if let currentImageURL = imageURL, !currentImageURL.hasPrefix("http") {
            if let baseURL = URL(string: currentImageURL, relativeTo: url) {
                imageURL = baseURL.absoluteString
            }
        }
        
        AppLogger.info("📋 Extracted metadata - Title: \(title ?? "none"), Description: \(description?.prefix(50) ?? "none")", category: AppConstants.LoggerCategory.urlMetadataFetcher)
        
        return URLMetadata(
            title: title,
            description: description,
            imageURL: imageURL,
            siteName: siteName,
            type: type,
            rawHTML: html
        )
    }
    
    /// Extract Open Graph tag value
    private func extractOpenGraphTag(html: String, property: String) -> String? {
        // Remove "og:" prefix if present
        let propertyName = property.replacingOccurrences(of: "og:", with: "")
        let pattern = #"<meta\s+property=["']og:\#(propertyName)["']\s+content=["']([^"']+)["']"#
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return nil
        }
        
        let range = NSRange(html.startIndex..., in: html)
        if let match = regex.firstMatch(in: html, options: [], range: range),
           let contentRange = Range(match.range(at: 1), in: html) {
            return String(html[contentRange])
        }
        
        return nil
    }
    
    /// Extract meta tag value by name
    private func extractMetaTag(html: String, name: String) -> String? {
        let pattern = #"<meta\s+name=["']\#(name)["']\s+content=["']([^"']+)["']"#
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return nil
        }
        
        let range = NSRange(html.startIndex..., in: html)
        if let match = regex.firstMatch(in: html, options: [], range: range),
           let contentRange = Range(match.range(at: 1), in: html) {
            return String(html[contentRange])
        }
        
        return nil
    }
    
    /// Extract content from HTML tag (e.g., <title>...</title>)
    private func extractHTMLTag(html: String, tag: String) -> String? {
        let pattern = #"<\#(tag)[^>]*>([^<]+)</\#(tag)>"#
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return nil
        }
        
        let range = NSRange(html.startIndex..., in: html)
        if let match = regex.firstMatch(in: html, options: [], range: range),
           let contentRange = Range(match.range(at: 1), in: html) {
            return String(html[contentRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        return nil
    }
}

