import SwiftUI
import UniformTypeIdentifiers

/// A view that presents a folder picker for selecting markdown source folders
struct FolderPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext

    @State private var isPickerPresented = false
    @State private var selectedURL: URL?
    @State private var sourceName = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var onSourceAdded: (() -> Void)?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Icon
                Image(systemName: "folder.badge.plus")
                    .font(.system(size: 60))
                    .foregroundStyle(.tint)
                    .padding(.top, 40)

                // Instructions
                VStack(spacing: 8) {
                    Text("Add Markdown Source")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("Select a folder in iCloud Drive containing your markdown files. Chips will monitor this folder for changes.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                // Selected folder display
                if let url = selectedURL {
                    VStack(spacing: 12) {
                        HStack {
                            Image(systemName: "folder.fill")
                                .foregroundStyle(.blue)
                            Text(url.lastPathComponent)
                                .fontWeight(.medium)
                            Spacer()
                            Button {
                                selectedURL = nil
                                sourceName = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding()
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)

                        // Custom name field
                        TextField("Display Name (optional)", text: $sourceName)
                            .textFieldStyle(.roundedBorder)
                            .padding(.horizontal)
                    }
                }

                Spacer()

                // Error message
                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                }

                // Action buttons
                VStack(spacing: 12) {
                    if selectedURL == nil {
                        Button {
                            isPickerPresented = true
                        } label: {
                            Label("Choose Folder", systemImage: "folder")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    } else {
                        Button {
                            addSource()
                        } label: {
                            if isLoading {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                            } else {
                                Text("Add Source")
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(isLoading)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 32)
            }
            .navigationTitle("Add Source")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .fileImporter(
                isPresented: $isPickerPresented,
                allowedContentTypes: [.folder],
                allowsMultipleSelection: false
            ) { result in
                handleFolderSelection(result)
            }
        }
    }

    private func handleFolderSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            selectedURL = url
            sourceName = url.deletingPathExtension().lastPathComponent

        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }

    private func addSource() {
        guard let url = selectedURL else { return }

        isLoading = true
        errorMessage = nil

        Task {
            do {
                try await MarkdownSourceManager.shared.addSource(
                    url: url,
                    name: sourceName.isEmpty ? nil : sourceName,
                    context: viewContext
                )

                await MainActor.run {
                    onSourceAdded?()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
}

// MARK: - macOS Document Picker

#if os(macOS)
import AppKit

struct DocumentPicker: NSViewRepresentable {
    @Binding var selectedURL: URL?

    func makeNSView(context: Context) -> NSView {
        return NSView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject {
        let parent: DocumentPicker

        init(_ parent: DocumentPicker) {
            self.parent = parent
        }

        func showPicker() {
            let panel = NSOpenPanel()
            panel.canChooseFiles = false
            panel.canChooseDirectories = true
            panel.allowsMultipleSelection = false
            panel.canCreateDirectories = false
            panel.prompt = "Select"
            panel.message = "Choose a folder containing markdown files"

            if panel.runModal() == .OK {
                parent.selectedURL = panel.url
            }
        }
    }
}
#endif

// MARK: - Preview

#Preview {
    FolderPickerView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
