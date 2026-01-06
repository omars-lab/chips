import UIKit
import Social
import UniformTypeIdentifiers

/// Share Extension for adding items to Chips from other apps
class ShareViewController: UIViewController {

    // MARK: - UI Elements

    private let containerView = UIView()
    private let titleLabel = UILabel()
    private let contentPreview = UILabel()
    private let tagsTextField = UITextField()
    private let cancelButton = UIButton(type: .system)
    private let saveButton = UIButton(type: .system)
    private let activityIndicator = UIActivityIndicatorView(style: .medium)

    // MARK: - Data

    private var sharedURL: URL?
    private var sharedText: String?
    private var sharedTitle: String?

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        extractSharedContent()
    }

    // MARK: - UI Setup

    private func setupUI() {
        view.backgroundColor = UIColor.black.withAlphaComponent(0.4)

        // Container
        containerView.backgroundColor = .systemBackground
        containerView.layer.cornerRadius = 16
        containerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(containerView)

        // Title
        titleLabel.text = "Add to Chips"
        titleLabel.font = .boldSystemFont(ofSize: 17)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(titleLabel)

        // Content preview
        contentPreview.numberOfLines = 3
        contentPreview.font = .systemFont(ofSize: 14)
        contentPreview.textColor = .secondaryLabel
        contentPreview.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(contentPreview)

        // Tags field
        tagsTextField.placeholder = "Add tags (e.g., #cardio #workout)"
        tagsTextField.borderStyle = .roundedRect
        tagsTextField.autocapitalizationType = .none
        tagsTextField.autocorrectionType = .no
        tagsTextField.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(tagsTextField)

        // Cancel button
        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(cancelButton)

        // Save button
        saveButton.setTitle("Save", for: .normal)
        saveButton.titleLabel?.font = .boldSystemFont(ofSize: 17)
        saveButton.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(saveButton)

        // Activity indicator
        activityIndicator.hidesWhenStopped = true
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(activityIndicator)

        // Constraints
        NSLayoutConstraint.activate([
            containerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),

            contentPreview.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            contentPreview.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            contentPreview.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),

            tagsTextField.topAnchor.constraint(equalTo: contentPreview.bottomAnchor, constant: 16),
            tagsTextField.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            tagsTextField.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            tagsTextField.heightAnchor.constraint(equalToConstant: 44),

            cancelButton.topAnchor.constraint(equalTo: tagsTextField.bottomAnchor, constant: 16),
            cancelButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            cancelButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -16),

            saveButton.topAnchor.constraint(equalTo: tagsTextField.bottomAnchor, constant: 16),
            saveButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            saveButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -16),

            activityIndicator.centerXAnchor.constraint(equalTo: saveButton.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: saveButton.centerYAnchor)
        ])

        // Tap to dismiss keyboard
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tap)
    }

    // MARK: - Content Extraction

    private func extractSharedContent() {
        guard let extensionItems = extensionContext?.inputItems as? [NSExtensionItem] else {
            return
        }

        for item in extensionItems {
            guard let attachments = item.attachments else { continue }

            for provider in attachments {
                // Try URL first
                if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    provider.loadItem(forTypeIdentifier: UTType.url.identifier) { [weak self] item, _ in
                        if let url = item as? URL {
                            DispatchQueue.main.async {
                                self?.sharedURL = url
                                self?.sharedTitle = url.host ?? url.absoluteString
                                self?.updatePreview()
                            }
                        }
                    }
                    return
                }

                // Try plain text
                if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                    provider.loadItem(forTypeIdentifier: UTType.plainText.identifier) { [weak self] item, _ in
                        if let text = item as? String {
                            DispatchQueue.main.async {
                                // Check if it's a URL string
                                if let url = URL(string: text), url.scheme != nil {
                                    self?.sharedURL = url
                                    self?.sharedTitle = url.host ?? text
                                } else {
                                    self?.sharedText = text
                                    self?.sharedTitle = String(text.prefix(50))
                                }
                                self?.updatePreview()
                            }
                        }
                    }
                    return
                }
            }
        }
    }

    private func updatePreview() {
        if let url = sharedURL {
            contentPreview.text = url.absoluteString
        } else if let text = sharedText {
            contentPreview.text = text
        }
    }

    // MARK: - Actions

    @objc private func cancelTapped() {
        extensionContext?.completeRequest(returningItems: nil)
    }

    @objc private func saveTapped() {
        saveButton.isHidden = true
        activityIndicator.startAnimating()
        tagsTextField.isEnabled = false

        saveToInbox { [weak self] success in
            DispatchQueue.main.async {
                self?.activityIndicator.stopAnimating()
                if success {
                    self?.extensionContext?.completeRequest(returningItems: nil)
                } else {
                    self?.saveButton.isHidden = false
                    self?.tagsTextField.isEnabled = true
                    self?.showError()
                }
            }
        }
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    // MARK: - Save to Inbox

    private func saveToInbox(completion: @escaping (Bool) -> Void) {
        // Build the markdown line
        var markdown = "- "

        if let url = sharedURL {
            let title = sharedTitle ?? url.absoluteString
            markdown += "[\(title)](\(url.absoluteString))"
        } else if let text = sharedText {
            markdown += text
        } else {
            completion(false)
            return
        }

        // Add tags
        let tags = tagsTextField.text ?? ""
        if !tags.isEmpty {
            markdown += " \(tags)"
        }

        markdown += "\n"

        // Get the shared container URL
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.chips.app"
        ) else {
            completion(false)
            return
        }

        let inboxURL = containerURL.appendingPathComponent("inbox.md")

        // Append to inbox file
        do {
            if FileManager.default.fileExists(atPath: inboxURL.path) {
                let handle = try FileHandle(forWritingTo: inboxURL)
                handle.seekToEndOfFile()
                if let data = markdown.data(using: .utf8) {
                    handle.write(data)
                }
                handle.closeFile()
            } else {
                // Create new file with header
                let header = """
                ---
                title: Inbox
                category: inbox
                ---

                # Shared Items


                """
                let content = header + markdown
                try content.write(to: inboxURL, atomically: true, encoding: .utf8)
            }

            // Notify main app via UserDefaults
            if let defaults = UserDefaults(suiteName: "group.com.chips.app") {
                defaults.set(Date(), forKey: "lastShareDate")
            }

            completion(true)
        } catch {
            print("Failed to save to inbox: \(error)")
            completion(false)
        }
    }

    private func showError() {
        let alert = UIAlertController(
            title: "Error",
            message: "Failed to save. Please try again.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
