# Debugging Summary Feature

## Why "Generate Summary" Might Not Appear

The "Generate Summary" option appears in the context menu when:
1. Chip has `actionData?.url` set, OR
2. Chip title is a valid URL (starts with http:// or https://)

### Check Chip URL Detection

Add this debug code to see what's happening:

```swift
// In ChipRowView, add debug logging
let hasURL = chip.actionData?.url != nil || extractURL(from: chip.unwrappedTitle) != nil
print("🔍 [ChipRowView] Chip: \(chip.unwrappedTitle)")
print("   actionData?.url: \(chip.actionData?.url ?? "nil")")
print("   extractURL from title: \(extractURL(from: chip.unwrappedTitle) ?? "nil")")
print("   hasURL: \(hasURL)")
```

## How URL Metadata Fetching Works

The system now fetches metadata (like curl) when no description is present:

### 1. **URLMetadataFetcher** - Fetches metadata from URLs
   - Extracts Open Graph tags (`og:title`, `og:description`, `og:image`)
   - Extracts HTML meta tags (`<meta name="description">`)
   - Extracts HTML title tag (`<title>`)
   - Similar to what `curl` + HTML parsing would do

### 2. **Flow When Generating Summary**

```
1. User clicks "Generate Summary"
   ↓
2. ChipSummaryService.generateSummary() called
   ↓
3. Extract URL from chip (actionData or title)
   ↓
4. If no description provided:
   → Fetch URLMetadataFetcher.fetchMetadata()
   → Extract og:description or meta description
   → Use as description for summarization
   ↓
5. URLSummarizer.summarizeURL() called
   ↓
6. If description available:
   → Summarize description directly
   Else:
   → Fetch full HTML content
   → Extract text from HTML
   → Summarize extracted text
   ↓
7. Store summary in chip metadata
```

## Testing URL Metadata Fetching

You can test the metadata fetcher directly:

```swift
let metadataFetcher = URLMetadataFetcher.shared
if let metadata = await metadataFetcher.fetchMetadata(from: url) {
    print("Title: \(metadata.title ?? "none")")
    print("Description: \(metadata.description ?? "none")")
    print("Image: \(metadata.imageURL ?? "none")")
    print("Site: \(metadata.siteName ?? "none")")
}
```

## Common Issues

### Issue: "Generate Summary" not appearing

**Check:**
1. Does chip have `actionType == "url"`?
2. Does chip have `actionPayload` with URL?
3. Is chip title a valid URL?

**Debug:**
```swift
print("Chip actionType: \(chip.actionType ?? "nil")")
print("Chip actionPayload: \(chip.actionPayload ?? "nil")")
print("Chip actionData: \(chip.actionData?.url ?? "nil")")
print("Chip title: \(chip.unwrappedTitle)")
```

### Issue: Summary generation fails

**Check console logs:**
- Look for `📝 [ChipSummaryService]` messages
- Look for `📡 [ChipSummaryService] Fetching metadata...`
- Look for `📄 [ChipSummaryService] Summarizing URL...`
- Look for `⚠️` error messages

**Common causes:**
- Network error (URL unreachable)
- Invalid URL format
- Content type not HTML
- HTML parsing failed

### Issue: Metadata not found

**Check:**
- Does the URL return HTML?
- Does it have Open Graph tags?
- Check with: `curl -I <url>` to see headers

## Example: YouTube Video

For a YouTube video URL like `https://youtu.be/xAfp-znTRx8`:

1. **Metadata fetch** will get:
   - `og:title`: Video title
   - `og:description`: Video description
   - `og:image`: Thumbnail URL

2. **Summary generation** will:
   - Use `og:description` if available
   - Fall back to `og:title` if no description
   - Fall back to full HTML extraction if neither available

## Manual Testing

Test with a known URL:

```bash
# Test metadata extraction
curl -s "https://youtu.be/xAfp-znTRx8" | grep -i "og:title\|og:description" | head -5
```

In the app:
1. Right-click a chip with URL
2. Select "Generate Summary"
3. Check console for debug output
4. Summary should appear below chip title

