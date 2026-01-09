import SwiftUI
import CoreData

/// Shared component for displaying chips in list or grid layout
struct ChipListView: View {
    let source: ChipSource?
    let searchText: String
    let useGridLayout: Bool

    @Environment(\.managedObjectContext) private var viewContext

    var chips: [Chip] {
        guard let source = source else { return [] }
        var result = source.chipsArray

        if !searchText.isEmpty {
            result = result.filter {
                $0.unwrappedTitle.localizedCaseInsensitiveContains(searchText)
            }
        }

        return result
    }

    var groupedChips: [(String, [Chip])] {
        let grouped = Dictionary(grouping: chips) { $0.sectionTitle ?? "General" }
        return grouped.sorted { $0.key < $1.key }
    }

    var body: some View {
        if chips.isEmpty {
            if searchText.isEmpty {
                ContentUnavailableView(
                    "No Chips",
                    systemImage: "square.grid.2x2",
                    description: Text("Chips from your markdown files will appear here.")
                )
            } else {
                ContentUnavailableView.search(text: searchText)
            }
        } else if useGridLayout {
            // Grid layout for iPad/Mac
            gridLayout
        } else {
            // List layout for iPhone
            listLayout
        }
    }
    
    private var gridLayout: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                ForEach(groupedChips, id: \.0) { section, sectionChips in
                    VStack(alignment: .leading, spacing: 12) {
                        Text(section)
                            .font(.title2)
                            .fontWeight(.semibold)
                            .padding(.horizontal)
                        
                        ChipGridView(chips: sectionChips, sectionTitle: section)
                    }
                }
            }
            .padding(.vertical)
        }
        .background(platformBackgroundColor)
    }
    
    private var listLayout: some View {
        List {
            ForEach(groupedChips, id: \.0) { section, sectionChips in
                Section(section) {
                    ForEach(sectionChips) { chip in
                        ChipRowView(chip: chip)
                    }
                }
            }
        }
        .listStyle(platformListStyle)
    }
    
    private var platformBackgroundColor: Color {
        #if os(iOS)
        return Color(uiColor: .systemGroupedBackground)
        #else
        return Color(nsColor: .windowBackgroundColor)
        #endif
    }
    
    private var platformListStyle: some ListStyle {
        #if os(iOS)
        return .insetGrouped
        #else
        return .sidebar
        #endif
    }
}

