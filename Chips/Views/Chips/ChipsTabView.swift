import SwiftUI
import CoreData

/// Router view that delegates to platform-specific implementations
struct ChipsTabView: View {
    @StateObject private var viewModel = ChipsTabViewModel()

    var body: some View {
        #if os(iOS)
        if UIDevice.current.userInterfaceIdiom == .pad {
            ChipsTabView_iPad(viewModel: viewModel)
        } else {
            ChipsTabView_iOS(viewModel: viewModel)
        }
        #elseif os(macOS)
        ChipsTabView_macOS(viewModel: viewModel)
        #endif
    }
}

#Preview {
    ChipsTabView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
