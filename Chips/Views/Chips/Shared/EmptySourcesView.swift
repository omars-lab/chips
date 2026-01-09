import SwiftUI

/// Shared component for empty state when no sources exist
struct EmptySourcesView: View {
    @Binding var showingSourcePicker: Bool

    var body: some View {
        ContentUnavailableView {
            Label("No Sources", systemImage: "doc.text.magnifyingglass")
        } description: {
            Text("Add a folder from iCloud Drive containing your markdown files.")
        } actions: {
            Button("Add Source") {
                showingSourcePicker = true
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

