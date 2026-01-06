import SwiftUI

@main
struct ChipsApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
        #if os(macOS)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
        #endif
    }
}
