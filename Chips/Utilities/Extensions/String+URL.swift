import Foundation

extension String {
    /// Extracts a URL from the string if it's a valid URL
    /// - Returns: The URL string if valid, nil otherwise
    func extractURL() -> String? {
        let trimmed = self.trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = URL(string: trimmed), url.scheme != nil {
            return trimmed
        }
        return nil
    }
}

