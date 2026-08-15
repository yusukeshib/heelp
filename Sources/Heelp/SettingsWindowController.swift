import AppKit

@MainActor
final class SettingsWindowController: NSWindowController {
    var onSave: (() -> Void)?

    private struct ProviderDraft {
        var apiKey: String
        var model: String
        var thinkingLevel: String
    }

    private let settings: AppSettings
    private let promptSettings: PromptSettingsViewController
    private let providerPopUp = NSPopUpButton(frame: .zero, pullsDown: false)
    private let apiKeyLabel = NSTextField(labelWithString: "API key")
    private let apiKeyField = NSSecureTextField()
    private let modelField = NSTextField()
    private let thinkingLevelLabel = NSTextField(labelWithString: "Thinking level (empty to omit)")
    private let thinkingLevelField = NSTextField()
    private var displayedProvider: AIProvider = .anthropic
    private var drafts: [AIProvider: ProviderDraft] = [:]

    init(settings: AppSettings) {
        self.settings = settings
        promptSettings = PromptSettingsViewController(settings: settings)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 500),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Heelp Settings"
        window.isReleasedWhenClosed = false
        window.center()
        super.init(window: window)

        promptSettings.onSave = { [weak self] in
            self?.onSave?()
        }

        buildUI(in: window)
        loadValues()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func present() {
        loadValues()
        promptSettings.loadValues()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    private func buildUI(in window: NSWindow) {
        guard let content = window.contentView else { return }

        let tabView = NSTabView()
        tabView.translatesAutoresizingMaskIntoConstraints = false

        let generalItem = NSTabViewItem(identifier: "general")
        generalItem.label = "General"
        generalItem.view = makeGeneralView()
        tabView.addTabViewItem(generalItem)

        let promptsItem = NSTabViewItem(identifier: "prompts")
        promptsItem.label = "Prompts"
        promptsItem.view = promptSettings.view
        tabView.addTabViewItem(promptsItem)

        let systemPromptItem = NSTabViewItem(identifier: "systemPrompt")
        systemPromptItem.label = "System Prompt"
        systemPromptItem.view = makeSystemPromptView()
        tabView.addTabViewItem(systemPromptItem)

        content.addSubview(tabView)
        NSLayoutConstraint.activate([
            tabView.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),
            tabView.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -16),
            tabView.topAnchor.constraint(equalTo: content.topAnchor, constant: 16),
            tabView.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -16)
        ])
    }

    private func makeGeneralView() -> NSView {
        let content = NSView()

        let subtitle = NSTextField(
            wrappingLabelWithString: "Select text in any app, then click the Heelp button nearby to review it."
        )
        subtitle.textColor = .secondaryLabelColor

        providerPopUp.addItems(withTitles: AIProvider.allCases.map(\.displayName))
        providerPopUp.target = self
        providerPopUp.action = #selector(providerChanged(_:))

        styleLabel(apiKeyLabel)
        styleLabel(thinkingLevelLabel)
        modelField.placeholderString = "Model ID"
        thinkingLevelField.placeholderString = "none"

        let updateButton = NSButton(title: "Update", target: self, action: #selector(update))
        updateButton.keyEquivalent = "\r"
        let buttonRow = NSStackView()
        buttonRow.orientation = .horizontal
        buttonRow.alignment = .centerY
        buttonRow.spacing = 8
        buttonRow.addArrangedSubview(NSView())
        buttonRow.addArrangedSubview(updateButton)

        let stack = NSStackView(views: [
            subtitle,
            label("Provider"),
            providerPopUp,
            apiKeyLabel,
            apiKeyField,
            label("Model ID"),
            modelField,
            thinkingLevelLabel,
            thinkingLevelField,
            buttonRow
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 9
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: content.bottomAnchor, constant: -16),
            subtitle.widthAnchor.constraint(equalTo: stack.widthAnchor),
            providerPopUp.widthAnchor.constraint(equalTo: stack.widthAnchor),
            apiKeyField.widthAnchor.constraint(equalTo: stack.widthAnchor),
            modelField.widthAnchor.constraint(equalTo: stack.widthAnchor),
            thinkingLevelField.widthAnchor.constraint(equalTo: stack.widthAnchor),
            buttonRow.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])

        return content
    }

    private func makeSystemPromptView() -> NSView {
        let content = NSView()

        let subtitle = NSTextField(
            wrappingLabelWithString: "This read-only prompt is sent with every review request."
        )
        subtitle.textColor = .secondaryLabelColor
        subtitle.translatesAutoresizingMaskIntoConstraints = false

        let textView = NSTextView()
        textView.string = ReviewPrompt.system
        textView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = false
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.textContainerInset = NSSize(width: 8, height: 8)

        let scrollView = NSScrollView()
        scrollView.borderType = .bezelBorder
        scrollView.hasVerticalScroller = true
        scrollView.documentView = textView
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        content.addSubview(subtitle)
        content.addSubview(scrollView)
        NSLayoutConstraint.activate([
            subtitle.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),
            subtitle.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -16),
            subtitle.topAnchor.constraint(equalTo: content.topAnchor, constant: 16),
            scrollView.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),
            scrollView.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -16),
            scrollView.topAnchor.constraint(equalTo: subtitle.bottomAnchor, constant: 12),
            scrollView.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -16)
        ])

        return content
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
                    model: settings.model(for: provider),
                    thinkingLevel: settings.thinkingLevel(for: provider)
                )
            )
        })
        displayedProvider = settings.provider
        providerPopUp.selectItem(withTitle: displayedProvider.displayName)
        showDraft(for: displayedProvider)
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
            model: modelField.stringValue,
            thinkingLevel: thinkingLevelField.stringValue
        )
    }

    private func showDraft(for provider: AIProvider) {
        let draft = drafts[provider] ?? ProviderDraft(
            apiKey: "",
            model: provider.defaultModel,
            thinkingLevel: AppSettings.defaultThinkingLevel
        )
        apiKeyLabel.stringValue = "\(provider.displayName) API key"
        apiKeyField.placeholderString = provider.apiKeyPlaceholder
        apiKeyField.stringValue = draft.apiKey
        modelField.placeholderString = provider.defaultModel
        modelField.stringValue = draft.model
        thinkingLevelField.stringValue = draft.thinkingLevel
        thinkingLevelLabel.isHidden = !provider.supportsThinkingLevel
        thinkingLevelField.isHidden = !provider.supportsThinkingLevel
    }

    @objc private func update() {
        captureDisplayedDraft()
        let provider = selectedProvider
        let draft = drafts[provider] ?? ProviderDraft(
            apiKey: "",
            model: provider.defaultModel,
            thinkingLevel: AppSettings.defaultThinkingLevel
        )
        let model = draft.model.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !model.isEmpty else {
            showAlert(message: "Model ID cannot be empty.")
            return
        }

        do {
            for configuredProvider in AIProvider.allCases {
                guard let configuredDraft = drafts[configuredProvider] else { continue }
                let configuredModel = configuredDraft.model
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                guard !configuredModel.isEmpty else {
                    showAlert(message: "Model ID cannot be empty.")
                    return
                }
                try KeychainStore.setAPIKey(
                    configuredDraft.apiKey.trimmingCharacters(in: .whitespacesAndNewlines),
                    for: configuredProvider
                )
                settings.setModel(configuredModel, for: configuredProvider)
                settings.setThinkingLevel(
                    configuredDraft.thinkingLevel.trimmingCharacters(in: .whitespacesAndNewlines),
                    for: configuredProvider
                )
            }
            settings.provider = provider
            onSave?()
        } catch {
            showAlert(message: error.localizedDescription)
        }
    }

    private func showAlert(message: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Could not update Heelp settings"
        alert.informativeText = message
        alert.beginSheetModal(for: window!)
    }
}
