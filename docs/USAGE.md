# Summary Feature Usage Guide

## Where to See Summaries in Action

### 1. **ChipRowView (List View)**

When viewing chips in list format:

1. **Right-click (or long-press) on a chip** that has a URL
2. In the context menu, you'll see:
   - **"Generate Summary"** - Creates a summary from the URL
   - **"Show Summary"** - Displays the generated summary
   - **"Hide Summary"** - Hides the summary

3. **After generating**, the summary appears below the chip title:
   ```
   [Chip Title]
   #tag1 #tag2
   [Summary text appears here...]
   ```

### 2. **Visual Indicators**

- **Loading State**: When generating, you'll see a progress indicator and "Generating summary..." text
- **Summary Display**: Once generated, the summary appears in smaller text below the chip title
- **Context Menu**: Summary options only appear for chips with URLs

### 3. **How to Test**

1. **Run the app**: `make run-mac-stdout` or `make run-ios`
2. **Find a chip with a URL** (like a YouTube video link)
3. **Right-click the chip** (macOS) or **long-press** (iOS)
4. **Select "Generate Summary"** from the context menu
5. **Wait a few seconds** for the summary to generate
6. **The summary will automatically appear** below the chip title
7. **Use "Show Summary" / "Hide Summary"** to toggle visibility

### 4. **Example Workflow**

```
1. User sees chip: "30 Min HIIT Workout"
   URL: https://youtu.be/xAfp-znTRx8

2. Right-clicks → "Generate Summary"

3. App fetches content from URL
   App extracts text from HTML
   App summarizes using Natural Language framework

4. Summary appears:
   "30 Min HIIT Workout"
   #cardio #hiit
   "This high-intensity interval training workout focuses on 
   cardiovascular fitness through alternating periods of intense 
   exercise and recovery."
```

### 5. **Where Summaries Are Stored**

Summaries are stored in the chip's `metadata` JSON field:

```json
{
  "tags": ["cardio", "hiit"],
  "summary": "This high-intensity interval training workout...",
  "summaryGeneratedAt": "2024-01-05T23:45:00Z"
}
```

### 6. **Programmatic Usage**

You can also generate summaries programmatically:

```swift
// In your view model or service
let chipSummaryService = ChipSummaryService.shared

// Generate summary
await chipSummaryService.generateSummary(
    for: chip,
    description: "Optional text description of the link",
    in: context
)

// Retrieve summary
if let summary = chipSummaryService.getSummary(for: chip) {
    print("Summary: \(summary)")
}
```

### 7. **Debugging**

To see summary generation in action:

1. **Check console logs** - Look for:
   ```
   📄 Summarizing URL: https://...
   🔗 Extracted URL from title: https://...
   ✅ Summary saved for chip
   ```

2. **Check chip metadata** - Inspect the chip's metadata field in Core Data

3. **Test with known URLs** - Try with YouTube videos, blog posts, etc.

## Troubleshooting

**Summary not generating?**
- Check that the chip has a valid URL
- Check console for error messages
- Verify network connectivity (for URL fetching)

**Summary not appearing?**
- Make sure you clicked "Show Summary" after generating
- Check that `showingSummary` state is true
- Verify summary was saved in chip metadata

**Summary quality poor?**
- Natural Language framework uses rule-based summarization
- Quality depends on source text structure
- Consider providing a text description for better results

