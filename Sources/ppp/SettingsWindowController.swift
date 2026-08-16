import AppKit

@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate, NSTextFieldDelegate {
    var onSave: (() -> Void)?

    private struct ProviderDraft: Equatable {
        var apiKey: String
        var model: String
        var thinkingLevel: String
    }

    private let settings: AppSettings
    private let promptSettings: PromptSettingsViewController
    private let providerPopUp = NSPopUpButton(frame: .zero, pullsDown: false)
    private let openRouterSignInButton = NSButton(
        title: L10n.string("Sign in with OpenRouter"),
        target: nil,
        action: nil
    )
    private let apiKeyLabel = NSTextField(labelWithString: L10n.string("API key"))
    private let apiKeyField = NSSecureTextField()
    private let modelField = NSTextField()
    private let thinkingLevelLabel = NSTextField(
        labelWithString: L10n.string("Thinking level (empty to omit)")
    )
    private let thinkingLevelField = NSTextField()
    private let revertButton = NSButton(title: L10n.string("Revert"), target: nil, action: nil)
    private let updateButton = NSButton(title: L10n.string("Update"), target: nil, action: nil)
    private var displayedProvider: AIProvider = .openRouter
    private var savedProvider: AIProvider = .openRouter
    private var drafts: [AIProvider: ProviderDraft] = [:]
    private var savedDrafts: [AIProvider: ProviderDraft] = [:]
    private var openRouterSignInTask: Task<Void, Never>?

    init(settings: AppSettings) {
        self.settings = settings
        promptSettings = PromptSettingsViewController(settings: settings)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 500),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = L10n.string("ppp Settings")
        window.isReleasedWhenClosed = false
        window.center()
        super.init(window: window)
        window.delegate = self

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

    func windowWillClose(_ notification: Notification) {
        openRouterSignInTask?.cancel()
    }

    private func buildUI(in window: NSWindow) {
        guard let content = window.contentView else { return }

        let tabView = NSTabView()
        tabView.translatesAutoresizingMaskIntoConstraints = false

        let generalItem = NSTabViewItem(identifier: "general")
        generalItem.label = L10n.string("General")
        generalItem.view = makeGeneralView()
        tabView.addTabViewItem(generalItem)

        let promptsItem = NSTabViewItem(identifier: "prompts")
        promptsItem.label = L10n.string("Prompts")
        promptsItem.view = promptSettings.view
        tabView.addTabViewItem(promptsItem)

        let systemPromptItem = NSTabViewItem(identifier: "systemPrompt")
        systemPromptItem.label = L10n.string("System Prompt")
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
            wrappingLabelWithString: L10n.string(
                "Select text in any app, then click the ppp button nearby to review it."
            )
        )
        subtitle.textColor = .secondaryLabelColor

        providerPopUp.addItems(withTitles: AIProvider.allCases.map(\.displayName))
        providerPopUp.target = self
        providerPopUp.action = #selector(providerChanged(_:))
        openRouterSignInButton.target = self
        openRouterSignInButton.action = #selector(signInWithOpenRouter)

        let providerRow = NSStackView(views: [providerPopUp, openRouterSignInButton])
        providerRow.orientation = .horizontal
        providerRow.alignment = .centerY
        providerRow.spacing = 8
        providerPopUp.setContentHuggingPriority(.defaultLow, for: .horizontal)
        openRouterSignInButton.setContentHuggingPriority(.required, for: .horizontal)

        styleLabel(apiKeyLabel)
        styleLabel(thinkingLevelLabel)
        apiKeyField.delegate = self
        modelField.delegate = self
        thinkingLevelField.delegate = self
        modelField.placeholderString = L10n.string("Model ID")
        thinkingLevelField.placeholderString = "none"

        revertButton.target = self
        revertButton.action = #selector(revert)
        revertButton.toolTip = L10n.string("Discard Unsaved Changes")
        updateButton.target = self
        updateButton.action = #selector(update)
        updateButton.keyEquivalent = "\r"
        let buttonRow = NSStackView(views: [NSView(), revertButton, updateButton])
        buttonRow.orientation = .horizontal
        buttonRow.alignment = .centerY
        buttonRow.spacing = 8

        let stack = NSStackView(views: [
            subtitle,
            label("Provider"),
            providerRow,
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
            providerRow.widthAnchor.constraint(equalTo: stack.widthAnchor),
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
            wrappingLabelWithString: L10n.string(
                "This read-only prompt is sent with every review request."
            )
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
        let field = NSTextField(labelWithString: L10n.string(value))
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
        savedProvider = displayedProvider
        savedDrafts = drafts
        providerPopUp.selectItem(withTitle: displayedProvider.displayName)
        showDraft(for: displayedProvider)
        updateGeneralButtons()
    }

    @objc private func providerChanged(_ sender: NSPopUpButton) {
        captureDisplayedDraft()
        displayedProvider = selectedProvider
        showDraft(for: displayedProvider)
        updateGeneralButtons()
    }

    func controlTextDidChange(_ notification: Notification) {
        guard let field = notification.object as? NSTextField,
              field === apiKeyField || field === modelField || field === thinkingLevelField
        else { return }
        captureDisplayedDraft()
        refreshOpenRouterSignInButton(for: displayedProvider)
        updateGeneralButtons()
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
        apiKeyLabel.stringValue = L10n.format("%@ API key", provider.displayName)
        apiKeyField.placeholderString = provider.apiKeyPlaceholder
        apiKeyField.stringValue = draft.apiKey
        modelField.placeholderString = provider.defaultModel
        modelField.stringValue = draft.model
        thinkingLevelField.stringValue = draft.thinkingLevel
        thinkingLevelLabel.isHidden = !provider.supportsThinkingLevel
        thinkingLevelField.isHidden = !provider.supportsThinkingLevel
        refreshOpenRouterSignInButton(for: provider)
    }

    private func refreshOpenRouterSignInButton(for provider: AIProvider) {
        openRouterSignInButton.isHidden = provider != .openRouter
        guard provider == .openRouter else { return }

        openRouterSignInButton.isEnabled = openRouterSignInTask == nil
        if openRouterSignInTask != nil {
            openRouterSignInButton.title = L10n.string("Connecting…")
        } else if drafts[.openRouter]?.apiKey
            .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        {
            openRouterSignInButton.title = L10n.string("Reconnect")
        } else {
            openRouterSignInButton.title = L10n.string("Connect")
        }
    }

    @objc private func signInWithOpenRouter() {
        guard displayedProvider == .openRouter, openRouterSignInTask == nil else { return }
        captureDisplayedDraft()

        openRouterSignInTask = Task { [weak self] in
            guard let self else { return }
            defer {
                openRouterSignInTask = nil
                refreshOpenRouterSignInButton(for: displayedProvider)
                updateGeneralButtons()
            }

            do {
                let apiKey = try await OpenRouterOAuthClient.signIn()
                try Task.checkCancellation()
                try KeychainStore.setAPIKey(apiKey, for: .openRouter)

                drafts[.openRouter]?.apiKey = apiKey
                savedDrafts[.openRouter]?.apiKey = apiKey
                if displayedProvider == .openRouter {
                    apiKeyField.stringValue = apiKey
                    settings.provider = .openRouter
                    savedProvider = .openRouter
                    onSave?()
                }
            } catch is CancellationError {
                return
            } catch {
                showAlert(
                    title: L10n.string("Could not sign in with OpenRouter"),
                    message: error.localizedDescription
                )
            }
        }
        refreshOpenRouterSignInButton(for: .openRouter)
        updateGeneralButtons()
    }

    @objc private func revert() {
        drafts = savedDrafts
        displayedProvider = savedProvider
        providerPopUp.selectItem(withTitle: displayedProvider.displayName)
        showDraft(for: displayedProvider)
        updateGeneralButtons()
    }

    @objc private func update() {
        captureDisplayedDraft()
        let provider = selectedProvider

        do {
            for configuredProvider in AIProvider.allCases {
                guard let configuredDraft = drafts[configuredProvider] else { continue }
                let normalizedDraft = ProviderDraft(
                    apiKey: configuredDraft.apiKey.trimmingCharacters(in: .whitespacesAndNewlines),
                    model: configuredDraft.model.trimmingCharacters(in: .whitespacesAndNewlines),
                    thinkingLevel: configuredDraft.thinkingLevel
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                )
                guard !normalizedDraft.model.isEmpty else {
                    showAlert(message: L10n.string("Model ID cannot be empty."))
                    return
                }
                try KeychainStore.setAPIKey(normalizedDraft.apiKey, for: configuredProvider)
                settings.setModel(normalizedDraft.model, for: configuredProvider)
                settings.setThinkingLevel(normalizedDraft.thinkingLevel, for: configuredProvider)
                drafts[configuredProvider] = normalizedDraft
            }
            settings.provider = provider
            savedProvider = provider
            savedDrafts = drafts
            showDraft(for: displayedProvider)
            updateGeneralButtons()
            onSave?()
        } catch {
            showAlert(message: error.localizedDescription)
        }
    }

    private func updateGeneralButtons() {
        let hasChanges = selectedProvider != savedProvider || drafts != savedDrafts
        let canApplyChanges = hasChanges && openRouterSignInTask == nil
        revertButton.isEnabled = canApplyChanges
        updateButton.isEnabled = canApplyChanges
    }

    private func showAlert(
        title: String = L10n.string("Could not update ppp settings"),
        message: String
    ) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = title
        alert.informativeText = message
        alert.beginSheetModal(for: window!)
    }
}
