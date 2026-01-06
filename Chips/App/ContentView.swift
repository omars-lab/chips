import SwiftUI

struct ContentView: View {
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif

    var body: some View {
        #if os(iOS)
        if horizontalSizeClass == .compact {
            TabBarNavigation()
        } else {
            SidebarNavigation()
        }
        #else
        SidebarNavigation()
        #endif
    }
}

// MARK: - Tab Bar Navigation (iPhone)
struct TabBarNavigation: View {
    @State private var selectedTab: AppTab = .chips

    var body: some View {
        TabView(selection: $selectedTab) {
            ChipsTabView()
                .tabItem {
                    Label("Chips", systemImage: "square.grid.2x2")
                }
                .tag(AppTab.chips)

            HistoryTabView()
                .tabItem {
                    Label("History", systemImage: "clock")
                }
                .tag(AppTab.history)

            SettingsTabView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(AppTab.settings)
        }
    }
}

// MARK: - Sidebar Navigation (iPad/Mac)
struct SidebarNavigation: View {
    @State private var selectedTab: AppTab? = .chips

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedTab) {
                // App Logo Header
                HStack {
                    Spacer()
                    PressableChipLogoView(size: 60, style: .appIcon) {
                        selectedTab = .chips
                    }
                    Spacer()
                }
                .padding(.vertical, 8)
                .listRowSeparator(.hidden)
                
                NavigationLink(value: AppTab.chips) {
                    Label("Chips", systemImage: "square.grid.2x2")
                }

                NavigationLink(value: AppTab.history) {
                    Label("History", systemImage: "clock")
                }

                NavigationLink(value: AppTab.settings) {
                    Label("Settings", systemImage: "gear")
                }
            }
            .navigationTitle("Chips")
            #if os(macOS)
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
            #endif
        } detail: {
            switch selectedTab {
            case .chips:
                ChipsTabView()
            case .history:
                HistoryTabView()
            case .settings:
                SettingsTabView()
            case .none:
                Text("Select a tab")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - App Tab Enum
enum AppTab: String, Hashable {
    case chips
    case history
    case settings
}

#Preview {
    ContentView()
}
