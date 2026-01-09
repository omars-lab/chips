import SwiftUI

/// Shared component for filter menu
struct FilterMenu: View {
    @State private var showCompleted = true
    @State private var selectedTags: Set<String> = []

    var body: some View {
        Menu {
            Toggle("Show Completed", isOn: $showCompleted)

            Divider()

            Menu("Tags") {
                Button("All Tags") {
                    selectedTags.removeAll()
                }
                // Tags would be populated dynamically
            }
        } label: {
            Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
        }
    }
}

