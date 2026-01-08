import Foundation

/// Extracts variables from source URLs for use in action templates
struct URLVariableExtractor {

    /// All available variables for a given URL
    struct ExtractedVariables {
        let sourceType: SourceType
        let variables: [String: String]

        enum SourceType: String, CaseIterable {
            case youtube = "YouTube"
            case github = "GitHub"
            case twitter = "Twitter/X"
            case spotify = "Spotify"
            case generic = "Generic URL"
        }

        /// Available variable names for this source type
        static func availableVariables(for type: SourceType) -> [(key: String, description: String)] {
            switch type {
            case .youtube:
                return [
                    ("url", "Full URL"),
                    ("video_id", "Video ID"),
                    ("title", "Chip title"),
                    ("timestamp", "Video timestamp (if present)")
                ]
            case .github:
                return [
                    ("url", "Full URL"),
                    ("owner", "Repository owner"),
                    ("repo", "Repository name"),
                    ("path", "File path (if present)"),
                    ("title", "Chip title")
                ]
            case .twitter:
                return [
                    ("url", "Full URL"),
                    ("username", "Username"),
                    ("tweet_id", "Tweet ID (if present)"),
                    ("title", "Chip title")
                ]
            case .spotify:
                return [
                    ("url", "Full URL"),
                    ("track_id", "Track/Album/Playlist ID"),
                    ("type", "Content type (track/album/playlist)"),
                    ("title", "Chip title")
                ]
            case .generic:
                return [
                    ("url", "Full URL"),
                    ("host", "Domain name"),
                    ("path", "URL path"),
                    ("title", "Chip title")
                ]
            }
        }
    }

    /// Extract variables from a URL string
    static func extract(from urlString: String, chipTitle: String) -> ExtractedVariables {
        guard let url = URL(string: urlString),
              let host = url.host?.lowercased() else {
            return ExtractedVariables(
                sourceType: .generic,
                variables: ["url": urlString, "title": chipTitle]
            )
        }

        // Determine the title to use
        // If chipTitle is the same as urlString (i.e., title is just the URL),
        // use a default title based on the source type
        var titleToUse = chipTitle
        let trimmedTitle = chipTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedURL = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        let isTitleJustURL = trimmedTitle == trimmedURL || trimmedTitle.isEmpty
        
        if isTitleJustURL {
            if host.contains("youtube.com") || host.contains("youtu.be") {
                titleToUse = "Youtube Video"
            } else if host.contains("github.com") {
                titleToUse = "GitHub Repository"
            } else if host.contains("twitter.com") || host.contains("x.com") {
                titleToUse = "Twitter Post"
            } else if host.contains("spotify.com") || host.contains("open.spotify.com") {
                titleToUse = "Spotify Track"
            }
        }

        let variables: [String: String] = [
            "url": urlString,
            "title": titleToUse,
            "host": host,
            "path": url.path
        ]

        // Detect source type and extract specific variables
        if host.contains("youtube.com") || host.contains("youtu.be") {
            return extractYouTube(url: url, urlString: urlString, base: variables)
        } else if host.contains("github.com") {
            return extractGitHub(url: url, base: variables)
        } else if host.contains("twitter.com") || host.contains("x.com") {
            return extractTwitter(url: url, base: variables)
        } else if host.contains("spotify.com") || host.contains("open.spotify.com") {
            return extractSpotify(url: url, base: variables)
        }

        return ExtractedVariables(sourceType: .generic, variables: variables)
    }

    // MARK: - YouTube

    private static func extractYouTube(url: URL, urlString: String, base: [String: String]) -> ExtractedVariables {
        var variables = base

        // Extract video ID
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            // youtube.com/watch?v=VIDEO_ID
            if let videoID = components.queryItems?.first(where: { $0.name == "v" })?.value {
                variables["video_id"] = videoID
            }
            // Extract timestamp (?t=123)
            if let timestamp = components.queryItems?.first(where: { $0.name == "t" })?.value {
                variables["timestamp"] = timestamp
            }
        }

        // youtu.be/VIDEO_ID
        if url.host == "youtu.be" {
            let videoID = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            if !videoID.isEmpty {
                variables["video_id"] = videoID
            }
        }

        return ExtractedVariables(sourceType: .youtube, variables: variables)
    }

    // MARK: - GitHub

    private static func extractGitHub(url: URL, base: [String: String]) -> ExtractedVariables {
        var variables = base

        let pathComponents = url.pathComponents.filter { $0 != "/" }

        if pathComponents.count >= 1 {
            variables["owner"] = pathComponents[0]
        }
        if pathComponents.count >= 2 {
            variables["repo"] = pathComponents[1]
        }
        if pathComponents.count > 2 {
            // Everything after owner/repo
            let remaining = pathComponents.dropFirst(2).joined(separator: "/")
            variables["path"] = remaining
        }

        return ExtractedVariables(sourceType: .github, variables: variables)
    }

    // MARK: - Twitter/X

    private static func extractTwitter(url: URL, base: [String: String]) -> ExtractedVariables {
        var variables = base

        let pathComponents = url.pathComponents.filter { $0 != "/" }

        if let firstComponent = pathComponents.first, !firstComponent.isEmpty {
            variables["username"] = firstComponent
        }

        // Check for tweet ID (e.g., /username/status/1234567890)
        if pathComponents.count >= 3 && pathComponents[1] == "status" {
            variables["tweet_id"] = pathComponents[2]
        }

        return ExtractedVariables(sourceType: .twitter, variables: variables)
    }

    // MARK: - Spotify

    private static func extractSpotify(url: URL, base: [String: String]) -> ExtractedVariables {
        var variables = base

        let pathComponents = url.pathComponents.filter { $0 != "/" }

        // open.spotify.com/track/ID or /album/ID or /playlist/ID
        if pathComponents.count >= 2 {
            variables["type"] = pathComponents[0] // track, album, playlist
            variables["track_id"] = pathComponents[1]
        }

        return ExtractedVariables(sourceType: .spotify, variables: variables)
    }

    // MARK: - Template Resolution

    /// Resolve a template string with extracted variables
    static func resolve(template: String, with variables: [String: String]) -> String {
        var result = template

        for (key, value) in variables {
            result = result.replacingOccurrences(of: "{{\(key)}}", with: value)
        }

        // URL encode the result for x-callback-url safety
        return result
    }
}
