# Summarization Feature Documentation

## Overview

The summarization feature allows you to generate summaries for chips that contain URLs. It uses Apple's Natural Language framework and can fetch metadata from URLs (like Open Graph tags) to provide better summaries.

## Features

- **URL Metadata Fetching**: Automatically fetches Open Graph tags, meta descriptions, and titles from URLs
- **Text Summarization**: Uses Natural Language framework to create concise summaries
- **Automatic Description Extraction**: If no description is provided, fetches metadata from the URL
- **Storage**: Summaries are stored in chip metadata for later retrieval

## Usage

### Generating Summaries

1. **Right-click (macOS) or long-press (iOS)** on a chip that has a URL
2. Select **"Generate Summary"** from the context menu
3. Wait a few seconds for the summary to generate
4. The summary will automatically appear below the chip title

### Viewing Summaries

- After generating, use **"Show Summary"** / **"Hide Summary"** in the context menu to toggle visibility
- Summaries appear below the chip title in smaller text

## How It Works

### 1. URL Detection

The system detects URLs in two ways:
- From `chip.actionData?.url` (if chip was created with a URL)
- From `chip.unwrappedTitle` (if title itself is a URL)

### 2. Metadata Fetching (Like curl)

When no description is provided, the system fetches metadata from the URL:

```swift
// Similar to: curl -s "https://example.com" | grep "og:description"
let metadata = await URLMetadataFetcher.shared.fetchMetadata(from: url)
// Extracts:
// - og:title, og:description, og:image
// - meta name="description"
// - <title> tag
```

### 3. Summarization

The system prioritizes content sources:
1. **Provided description** (if available)
2. **Open Graph description** (`og:description`)
3. **Meta description** (`<meta name="description">`)
4. **Open Graph title** (`og:title`)
5. **Full HTML content** (extracted and summarized)

### 4. Storage

Summaries are stored in chip metadata JSON:

```json
{
  "tags": ["cardio", "hiit"],
  "summary": "This high-intensity interval training workout...",
  "summaryGeneratedAt": "2024-01-05T23:45:00Z"
}
```

## Programmatic Usage

```swift
import NaturalLanguage

// Generate summary for a chip
let chipSummaryService = ChipSummaryService.shared

await chipSummaryService.generateSummary(
    for: chip,
    description: nil, // Will fetch metadata if nil
    in: context
)

// Retrieve summary
if let summary = chipSummaryService.getSummary(for: chip) {
    print("Summary: \(summary)")
}
```

## URL Metadata Fetcher

The `URLMetadataFetcher` extracts metadata similar to what `curl` would return:

```swift
let metadataFetcher = URLMetadataFetcher.shared

if let metadata = await metadataFetcher.fetchMetadata(from: url) {
    print("Title: \(metadata.title ?? "none")")
    print("Description: \(metadata.description ?? "none")")
    print("Image: \(metadata.imageURL ?? "none")")
    print("Site: \(metadata.siteName ?? "none")")
}
```

### What It Extracts

- **Open Graph tags**: `og:title`, `og:description`, `og:image`, `og:site_name`, `og:type`
- **HTML meta tags**: `<meta name="description">`
- **HTML title**: `<title>...</title>`

## Debugging

See [DEBUG.md](DEBUG.md) for detailed debugging information.

### Common Issues

**"Generate Summary" not appearing:**
- Check that chip has a URL (`actionData?.url` or title is a URL)
- Check console logs for debug messages

**Summary generation fails:**
- Check network connectivity
- Verify URL is accessible
- Check console for error messages

**Poor summary quality:**
- Natural Language framework uses rule-based summarization
- Quality depends on source text structure
- Providing a description improves results

## Testing

Test metadata extraction manually:

```bash
# Test Open Graph tags
curl -s "https://youtu.be/xAfp-znTRx8" | grep -i "og:title\|og:description" | head -5
```

## Requirements

- iOS 17+ / macOS 14+
- Natural Language framework (included)
- Network access (for URL fetching)

## See Also

- [DEBUG.md](DEBUG.md) - Debugging guide
- [APPLE_INTELLIGENCE.md](APPLE_INTELLIGENCE.md) - Apple Intelligence integration
- [USAGE.md](USAGE.md) - General usage guide

