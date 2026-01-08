import Foundation
import SwiftUI
import CoreData

/// ViewModel for individual chip views (shared between ChipRowView and ChipCardView)
/// Encapsulates all metadata, summary, and thumbnail logic
@MainActor
final class ChipViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var metadata: URLMetadataFetcher.URLMetadata?
    @Published var showingSummary = false
    @Published var isGeneratingSummary = false
    @Published var summary: String?
    @Published var showingMetadata = false
    @Published var isFetchingMetadata = false
    
    // MARK: - Chip Reference
    
    // Note: chip is observed by the view, not here, to avoid duplicate observation
    let chip: Chip
    private var viewContext: NSManagedObjectContext
    
    init(chip: Chip, context: NSManagedObjectContext) {
        self.chip = chip
        self.viewContext = context
    }
    
    /// Update the context reference (call from view's onAppear with environment context)
    func updateContext(_ context: NSManagedObjectContext) {
        self.viewContext = context
    }
    
    // MARK: - Computed Properties
    
    /// Display title - prefers metadata title if available, otherwise chip title
    var displayTitle: String {
        if let metadataTitle = metadata?.title, !metadataTitle.isEmpty {
            return metadataTitle
        }
        if let metadataTitle = chip.chipMetadata?.metadataTitle, !metadataTitle.isEmpty {
            return metadataTitle
        }
        return chip.unwrappedTitle
    }
    
    /// Thumbnail URL from either @Published metadata or chip stored metadata
    var thumbnailURL: String? {
        let stateURL = metadata?.imageURL
        let chipURL = chip.chipMetadata?.metadataImageURL
        let url = stateURL ?? chipURL
        
        if url != nil {
            print("🖼️ [ChipViewModel] thumbnailURL computed for '\(chip.unwrappedTitle)' - @Published: \(stateURL ?? "nil"), chip.chipMetadata: \(chipURL ?? "nil"), final: \(url ?? "nil")")
            fflush(stdout)
        }
        
        return url
    }
    
    /// Check if chip has a URL
    var hasURL: Bool {
        chip.actionData?.url != nil || chip.unwrappedTitle.extractURL() != nil
    }
    
    // MARK: - Metadata Loading
    
    /// Load metadata from chip's stored metadata JSON into @Published property
    func loadMetadataFromChip() {
        guard let chipMeta = chip.chipMetadata else {
            print("📥 [ChipViewModel] No existing chip metadata found to load.")
            fflush(stdout)
            return
        }
        
        // Reconstruct URLMetadata from stored chip metadata
        if chipMeta.metadataTitle != nil || chipMeta.metadataImageURL != nil {
            let reconstructedMetadata = URLMetadataFetcher.URLMetadata(
                title: chipMeta.metadataTitle,
                description: chipMeta.metadataDescription,
                imageURL: chipMeta.metadataImageURL,
                siteName: chipMeta.metadataSiteName,
                type: chipMeta.metadataType,
                rawHTML: nil
            )
            metadata = reconstructedMetadata
            print("📥 [ChipViewModel] Loaded metadata from chip storage into @Published.")
            print("   - Reconstructed imageURL: \(reconstructedMetadata.imageURL ?? "nil")")
            fflush(stdout)
        } else {
            print("📥 [ChipViewModel] Existing chip metadata found, but no title or imageURL to reconstruct.")
            fflush(stdout)
        }
    }
    
    // MARK: - Metadata Fetching
    
    /// Check and fetch metadata if not already present
    func checkAndFetchMetadata() async {
        // Early return if metadata already exists
        if metadata != nil {
            print("ℹ️ [ChipViewModel] Metadata already exists - skipping fetch")
            fflush(stdout)
            return
        }
        
        let urlFromActionData = chip.actionData?.url
        let urlFromTitle = chip.unwrappedTitle.extractURL()
        let urlString = urlFromActionData ?? urlFromTitle
        
        guard let urlString = urlString, let url = URL(string: urlString) else {
            print("❌ [ChipViewModel] No URL found - skipping metadata fetch")
            fflush(stdout)
            return
        }
        
        print("📡 [ChipViewModel] Fetching metadata for URL: \(urlString)")
        fflush(stdout)
        
        let fetchedMetadata = await URLMetadataFetcher.shared.fetchMetadata(from: url)
        
        if let fetchedMetadata = fetchedMetadata {
            print("✅ [ChipViewModel] Metadata fetched successfully:")
            print("   - Title: \(fetchedMetadata.title ?? "none")")
            print("   - Image URL: \(fetchedMetadata.imageURL ?? "none")")
            fflush(stdout)
            
            // Update chip with metadata
            await updateChipWithMetadata(fetchedMetadata, urlString: urlString)
            
            // Update @Published metadata for immediate UI update
            metadata = fetchedMetadata
            
            // Trigger summarization after metadata is fetched
            Task {
                await generateSummary(description: fetchedMetadata.description)
            }
        } else {
            print("⚠️ [ChipViewModel] Metadata fetch returned nil")
            fflush(stdout)
        }
    }
    
    /// Fetch and show metadata (for manual "View Metadata" action)
    func fetchAndShowMetadata() async {
        guard let urlString = chip.actionData?.url ?? chip.unwrappedTitle.extractURL(),
              let url = URL(string: urlString) else {
            print("❌ [ChipViewModel] fetchAndShowMetadata - no URL found")
            fflush(stdout)
            return
        }
        
        print("✅ [ChipViewModel] fetchAndShowMetadata - URL: \(urlString)")
        fflush(stdout)
        
        isFetchingMetadata = true
        defer { isFetchingMetadata = false }
        
        let fetchedMetadata = await URLMetadataFetcher.shared.fetchMetadata(from: url)
        
        if let fetchedMetadata = fetchedMetadata {
            print("✅ [ChipViewModel] Metadata fetched successfully - Title: \(fetchedMetadata.title ?? "none")")
            fflush(stdout)
            
            // Update chip with metadata
            await updateChipWithMetadata(fetchedMetadata, urlString: urlString)
            
            // Update @Published metadata for immediate display
            metadata = fetchedMetadata
            
            showingMetadata = true
        } else {
            print("⚠️ [ChipViewModel] Metadata fetch returned nil")
            fflush(stdout)
        }
    }
    
    /// Update chip with metadata and trigger summarization
    private func updateChipWithMetadata(_ urlMetadata: URLMetadataFetcher.URLMetadata, urlString: String) async {
        // Check if this is a YouTube video
        let isYouTube = urlString.contains("youtube.com") || urlString.contains("youtu.be")
        
        // Get current chip metadata or create new
        var chipMeta = chip.chipMetadata ?? ChipMetadata()
        
        // Store all metadata fields
        chipMeta.metadataTitle = urlMetadata.title
        chipMeta.metadataDescription = urlMetadata.description
        chipMeta.metadataImageURL = urlMetadata.imageURL
        chipMeta.metadataSiteName = urlMetadata.siteName
        chipMeta.metadataType = urlMetadata.type
        
        // If chip title is just the URL and this is YouTube, update chip.title with metadata title
        // IMPORTANT: Also store URL in actionData so it can still be found after title update
        if isYouTube, let metadataTitle = urlMetadata.title {
            let currentTitle = chip.unwrappedTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            if currentTitle == urlString || currentTitle.extractURL() != nil {
                chip.title = metadataTitle
                
                // Store URL in actionData so it can still be extracted after title update
                var actionData = chip.actionData ?? ActionPayload()
                if actionData.url == nil {
                    actionData.url = urlString
                    chip.actionData = actionData
                    print("💾 [ChipViewModel] Stored URL in actionData: \(urlString)")
                    fflush(stdout)
                }
                
                print("📝 [ChipViewModel] Updated chip title with metadata: \(metadataTitle)")
                fflush(stdout)
            }
        } else {
            // For non-YouTube URLs, also ensure URL is stored in actionData if title contains URL
            let currentTitle = chip.unwrappedTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            if currentTitle == urlString || currentTitle.extractURL() != nil {
                var actionData = chip.actionData ?? ActionPayload()
                if actionData.url == nil {
                    actionData.url = urlString
                    chip.actionData = actionData
                    print("💾 [ChipViewModel] Stored URL in actionData: \(urlString)")
                    fflush(stdout)
                }
            }
        }
        
        // Store metadata in chip.metadata JSON
        chip.chipMetadata = chipMeta
        
        // Save changes
        do {
            try viewContext.save()
            print("✅ [ChipViewModel] Chip saved successfully")
            fflush(stdout)
        } catch {
            print("❌ [ChipViewModel] Failed to save chip metadata: \(error.localizedDescription)")
            fflush(stdout)
        }
    }
    
    // MARK: - Summary Generation
    
    /// Generate summary for the chip
    func generateSummary(description: String? = nil) async {
        isGeneratingSummary = true
        defer { isGeneratingSummary = false }
        
        await ChipSummaryService.shared.generateSummary(
            for: chip,
            description: description,
            in: viewContext
        )
        
        summary = ChipSummaryService.shared.getSummary(for: chip)
        
        // Auto-show summary after generation
        if summary != nil {
            showingSummary = true
        }
    }
    
    // MARK: - Lifecycle
    
    /// Called when view appears - loads existing metadata and prefetches if needed
    func onAppear() {
        print("👁️ [ChipViewModel] View appeared for chip: '\(chip.unwrappedTitle)'")
        print("   - Chip ID: \(chip.id?.uuidString ?? "nil")")
        print("   - Current @Published metadata: \(metadata != nil ? "exists" : "nil")")
        print("   - chip.actionData?.url: \(chip.actionData?.url ?? "nil")")
        print("   - chip.chipMetadata exists: \(chip.chipMetadata != nil)")
        if let chipMeta = chip.chipMetadata {
            print("   - chip.chipMetadata.metadataImageURL: \(chipMeta.metadataImageURL ?? "nil")")
            print("   - chip.chipMetadata.metadataTitle: \(chipMeta.metadataTitle ?? "nil")")
        }
        fflush(stdout)
        
        // Load existing metadata from chip if available
        if metadata == nil {
            print("   📥 Attempting to load metadata from chip storage...")
            fflush(stdout)
            loadMetadataFromChip()
            print("   📥 After loadMetadataFromChip, @Published metadata: \(metadata != nil ? "exists" : "nil"), imageURL: \(metadata?.imageURL ?? "nil")")
            fflush(stdout)
        }
        
        // Prefetch metadata if URL is present and metadata not already loaded
        let hasURL = chip.actionData?.url != nil || chip.unwrappedTitle.extractURL() != nil
        if metadata == nil && hasURL {
            print("   ✅ Conditions met for prefetching metadata")
            fflush(stdout)
            Task {
                await checkAndFetchMetadata()
            }
        }
    }
    
    /// Called when chip.metadata changes - reloads metadata from chip
    func onMetadataChanged(oldValue: String?, newValue: String?) {
        print("🔄 [ChipViewModel] chip.metadata changed for '\(chip.unwrappedTitle)'")
        print("   - Old metadata: \(oldValue ?? "nil")")
        print("   - New metadata: \(newValue ?? "nil")")
        if let chipMeta = chip.chipMetadata {
            print("   - chip.chipMetadata.metadataImageURL: \(chipMeta.metadataImageURL ?? "nil")")
        }
        fflush(stdout)
        
        // Always reload metadata from chip when it changes
        loadMetadataFromChip()
    }
}

