import Foundation
import NaturalLanguage
import os.log

#if canImport(AppIntents)
import AppIntents
#endif

/// Service for summarizing text using Apple's Natural Language framework
/// and Apple Intelligence (when available)
@MainActor
final class TextSummarizer {
    static let shared = TextSummarizer()
    
    private init() {}
    
    /// Summarize text using Natural Language framework
    /// - Parameters:
    ///   - text: The text to summarize
    ///   - maxSentences: Maximum number of sentences in summary (default: 3)
    /// - Returns: A summary string, or nil if summarization fails
    func summarize(_ text: String, maxSentences: Int = 3) async -> String? {
        guard !text.isEmpty else { return nil }
        
        // Use Natural Language framework for basic summarization
        return await withCheckedContinuation { continuation in
            Task {
                let summary = await performSummarization(text: text, maxSentences: maxSentences)
                continuation.resume(returning: summary)
            }
        }
    }
    
    /// Perform summarization using Natural Language framework
    private func performSummarization(text: String, maxSentences: Int) async -> String? {
        // Split into sentences
        let tagger = NLTagger(tagSchemes: [.lexicalClass, .sentimentScore])
        tagger.string = text
        
        var sentences: [(text: String, importance: Double)] = []
        
        tagger.enumerateTags(
            in: text.startIndex..<text.endIndex,
            unit: .sentence,
            scheme: .lexicalClass
        ) { tag, tokenRange in
            let sentence = String(text[tokenRange])
            
            // Calculate importance score based on:
            // 1. Length (longer sentences often more informative)
            // 2. Word frequency (common words = less important)
            // 3. Position (first sentences often more important)
            
            let importance = calculateImportance(
                sentence: sentence,
                position: sentences.count,
                totalLength: text.count
            )
            
            sentences.append((sentence, importance))
            return true
        }
        
        // Sort by importance and take top sentences, then restore original order
        let topSentences = sentences
            .sorted { $0.importance > $1.importance }
            .prefix(maxSentences)
        
        // Restore original order for readability
        let sortedSentences = topSentences
            .sorted { firstIndex(of: $0.text, in: text) < firstIndex(of: $1.text, in: text) }
            .map { $0.text }
        
        return sortedSentences.joined(separator: " ")
    }
    
    /// Calculate importance score for a sentence
    private func calculateImportance(
        sentence: String,
        position: Int,
        totalLength: Int
    ) -> Double {
        var score: Double = 0.0
        
        // Length factor (normalized)
        let lengthFactor = min(Double(sentence.count) / 100.0, 1.0)
        score += lengthFactor * 0.3
        
        // Position factor (earlier sentences are more important)
        let positionFactor = max(0, 1.0 - (Double(position) / 10.0))
        score += positionFactor * 0.2
        
        // Keyword density (look for important words)
        let keywords = ["important", "key", "summary", "conclusion", "result", "find", "show"]
        let keywordCount = keywords.reduce(0) { count, keyword in
            count + (sentence.lowercased().components(separatedBy: keyword).count - 1)
        }
        score += min(Double(keywordCount) * 0.1, 0.3)
        
        // Avoid very short sentences
        if sentence.count < 20 {
            score *= 0.5
        }
        
        return score
    }
    
    /// Find first index of a substring in text (for maintaining sentence order)
    private func firstIndex(of substring: String, in text: String) -> Int {
        guard let range = text.range(of: substring) else { return Int.max }
        return text.distance(from: text.startIndex, to: range.lowerBound)
    }
}

#if canImport(AppIntents) && os(iOS)
/// Apple Intelligence-powered summarization using App Intents
/// Available on iOS 18+ with Apple Intelligence
@available(iOS 18.0, *)
extension TextSummarizer {
    /// Summarize using Apple Intelligence (if available)
    /// This uses the system's AI capabilities through App Intents
    func summarizeWithAppleIntelligence(_ text: String) async -> String? {
        // Note: Direct Apple Intelligence APIs are limited
        // This would typically be done through:
        // 1. Siri integration via App Intents
        // 2. System share extensions
        // 3. Private Cloud Compute APIs (limited availability)
        
        // For now, fall back to Natural Language framework
        return await summarize(text)
    }
}
#endif

