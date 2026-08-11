import AppKit

@MainActor
final class SettingsWindowController: NSWindowController {
    var onSave: (() -> Void)?

    private struct ProviderDraft {
        var apiKey: String
        var model: String
    }

    private let settings: AppSettings
    private let providerPopUp = NSPopUpButton(frame: .zero, pullsDown: false)
    private let apiKeyLabel = NSTextField(labelWithString: "API key")
    private let apiKeyField = NSSecureTextField()
    private let modelField = NSTextField()
    private let promptTextView = NSTextView()
    private var displayedProvider: AIProvider = .anthropic
    private var drafts: [AIProvider: ProviderDraft] = [:]

    init(settings: AppSettings) {
        self.settings = settings

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 580, height: 580),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Jogen Settings"
        window.isReleasedWhenClosed = false
        window.center()
        super.init(window: window)

        buildUI(in: window)
        loadValues()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func present() {
        loadValues()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    private func buildUI(in window: NSWindow) {
        guard let content = window.contentView else { return }

        let title = NSTextField(labelWithString: "Jogen Settings")
        title.font = .systemFont(ofSize: 20, weight: .semibold)

        let subtitle = NSTextField(wrappingLabelWithString: "Select text in any app, then click the Jogen button nearby to review it.")
        subtitle.textColor = .secondaryLabelColor

        providerPopUp.addItems(withTitles: AIProvider.allCases.map(\.displayName))
        providerPopUp.target = self
        providerPopUp.action = #selector(providerChanged(_:))

        styleLabel(apiKeyLabel)
        modelField.placeholderString = "Model ID"

        promptTextView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        promptTextView.isRichText = false
        promptTextView.isAutomaticQuoteSubstitutionEnabled = false
        promptTextView.isAutomaticDashSubstitutionEnabled = false
        promptTextView.isVerticallyResizable = true
        promptTextView.isHorizontallyResizable = false
        promptTextView.autoresizingMask = [.width]
        promptTextView.textContainer?.widthTracksTextView = true
        promptTextView.textContainerInset = NSSize(width: 6, height: 6)

        let promptScroll = NSScrollView()
        promptScroll.borderType = .bezelBorder
        promptScroll.hasVerticalScroller = true
        promptScroll.documentView = promptTextView
        promptScroll.translatesAutoresizingMaskIntoConstraints = false
        promptScroll.heightAnchor.constraint(equalToConstant: 210).isActive = true

        let resetButton = NSButton(title: "Reset Prompt", target: self, action: #selector(resetPrompt))
        let saveButton = NSButton(title: "Save", target: self, action: #selector(save))
        saveButton.keyEquivalent = "\r"
        let buttonRow = NSStackView()
        buttonRow.orientation = .horizontal
        buttonRow.alignment = .centerY
        buttonRow.spacing = 8
        buttonRow.addArrangedSubview(resetButton)
        buttonRow.addArrangedSubview(NSView())
        buttonRow.addArrangedSubview(saveButton)

        let stack = NSStackView(views: [
            title,
            subtitle,
            label("Provider"),
            providerPopUp,
            apiKeyLabel,
            apiKeyField,
            label("Model ID"),
            modelField,
            label("Custom prompt"),
            promptScroll,
            buttonRow
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 9
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 22),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -22),
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 20),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: content.bottomAnchor, constant: -18),
            subtitle.widthAnchor.constraint(equalTo: stack.widthAnchor),
            providerPopUp.widthAnchor.constraint(equalTo: stack.widthAnchor),
            apiKeyField.widthAnchor.constraint(equalTo: stack.widthAnchor),
            modelField.widthAnchor.constraint(equalTo: stack.widthAnchor),
            promptScroll.widthAnchor.constraint(equalTo: stack.widthAnchor),
            buttonRow.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
    }

    private func label(_ value: String) -> NSTextField {
        let field = NSTextField(labelWithString: value)
        styleLabel(field)
        return field
    }

    private func styleLabel(_ field: NSTextField) {
        field.font = .systemFont(ofSize: 12, weight: .medium)
    }

    private func loadValues() {
        drafts = Dictionary(uniqueKeysWithValues: AIProvider.allCases.map { provider in
            (
                provider,
                ProviderDraft(
                    apiKey: KeychainStore.apiKey(for: provider),
                    model: settings.model(for: provider)
                )
            )
        })
        displayedProvider = settings.provider
        providerPopUp.selectItem(withTitle: displayedProvider.displayName)
        showDraft(for: displayedProvider)

        promptTextView.string = settings.prompt
    }

    @objc private func providerChanged(_ sender: NSPopUpButton) {
        captureDisplayedDraft()
        displayedProvider = selectedProvider
        showDraft(for: displayedProvider)
    }

    private var selectedProvider: AIProvider {
        let providers = AIProvider.allCases
        let selectedIndex = providerPopUp.indexOfSelectedItem
        guard providers.indices.contains(selectedIndex) else { return displayedProvider }
        return providers[selectedIndex]
    }

    private func captureDisplayedDraft() {
        drafts[displayedProvider] = ProviderDraft(
            apiKey: apiKeyField.stringValue,
            model: modelField.stringValue
        )
    }

    private func showDraft(for provider: AIProvider) {
        let draft = drafts[provider] ?? ProviderDraft(apiKey: "", model: provider.defaultModel)
        apiKeyLabel.stringValue = "\(provider.displayName) API key"
        apiKeyField.placeholderString = provider.apiKeyPlaceholder
        apiKeyField.stringValue = draft.apiKey
        modelField.placeholderString = provider.defaultModel
        modelField.stringValue = draft.model
    }

    @objc private func resetPrompt() {
        promptTextView.string = AppSettings.defaultPrompt
    }

    @objc private func save() {
        captureDisplayedDraft()
        let provider = selectedProvider
        let draft = drafts[provider] ?? ProviderDraft(apiKey: "", model: provider.defaultModel)
        let model = draft.model.trimmingCharacters(in: .whitespacesAndNewlines)
        let prompt = promptTextView.string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !model.isEmpty, !prompt.isEmpty else {
            showAlert(message: "Model ID and custom prompt cannot be empty.")
            return
        }

        do {
            for configuredProvider in AIProvider.allCases {
                guard let configuredDraft = drafts[configuredProvider] else { continue }
                let configuredModel = configuredDraft.model
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                guard !configuredModel.isEmpty else {
                    showAlert(message: "Model ID and custom prompt cannot be empty.")
                    return
                }
                try KeychainStore.setAPIKey(
                    configuredDraft.apiKey.trimmingCharacters(in: .whitespacesAndNewlines),
                    for: configuredProvider
                )
                settings.setModel(configuredModel, for: configuredProvider)
            }
            settings.provider = provider
            settings.prompt = prompt
            onSave?()
            window?.orderOut(nil)
        } catch {
            showAlert(message: error.localizedDescription)
        }
    }

    private func showAlert(message: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Could not save Jogen settings"
        alert.informativeText = message
        alert.beginSheetModal(for: window!)
    }
}
