import Foundation
import SwiftUI
import CoreData

/// ViewModel for ChipsTabView - shared state across all platforms
@MainActor
final class ChipsTabViewModel: ObservableObject {
    @Published var selectedSource: ChipSource?
    @Published var searchText = ""
    @Published var showingSourcePicker = false
    @Published var showingInboxSheet = false
    
    init() {}
}

