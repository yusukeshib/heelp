import AppKit

@MainActor
final class SettingsWindowController: NSWindowController {
    var onSave: (() -> Void)?

    private let settings: AppSettings
    private let apiKeyField = NSSecureTextField()
    private let modelField = NSTextField()
    private let promptTextView = NSTextView()
    private let debounceField = NSTextField()
    private let diagnosticButton = NSButton(
        checkboxWithTitle: "Diagnostic mode (show captured text without calling the API)",
        target: nil,
        action: nil
    )

    init(settings: AppSettings) {
        self.settings = settings

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 580, height: 590),
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

        let title = NSTextField(labelWithString: "Writing feedback")
        title.font = .systemFont(ofSize: 20, weight: .semibold)

        let subtitle = NSTextField(wrappingLabelWithString: "Select text in any app to review it. Jogen waits briefly for the selection to settle, then shows advice nearby.")
        subtitle.textColor = .secondaryLabelColor

        apiKeyField.placeholderString = "sk-ant-…"
        modelField.placeholderString = "Anthropic model ID"
        debounceField.alignment = .right

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

        let debounceRow = NSStackView()
        debounceRow.orientation = .horizontal
        debounceRow.alignment = .centerY
        debounceRow.spacing = 8
        debounceRow.addArrangedSubview(debounceField)
        debounceField.widthAnchor.constraint(equalToConstant: 72).isActive = true
        debounceRow.addArrangedSubview(NSTextField(labelWithString: "milliseconds"))
        debounceRow.addArrangedSubview(NSView())

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
            label("Anthropic API key"),
            apiKeyField,
            label("Model ID"),
            modelField,
            label("Custom prompt"),
            promptScroll,
            label("Selection delay"),
            debounceRow,
            diagnosticButton,
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
            apiKeyField.widthAnchor.constraint(equalTo: stack.widthAnchor),
            modelField.widthAnchor.constraint(equalTo: stack.widthAnchor),
            promptScroll.widthAnchor.constraint(equalTo: stack.widthAnchor),
            debounceRow.widthAnchor.constraint(equalTo: stack.widthAnchor),
            diagnosticButton.widthAnchor.constraint(equalTo: stack.widthAnchor),
            buttonRow.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
    }

    private func label(_ value: String) -> NSTextField {
        let field = NSTextField(labelWithString: value)
        field.font = .systemFont(ofSize: 12, weight: .medium)
        return field
    }

    private func loadValues() {
        apiKeyField.stringValue = KeychainStore.apiKey()
        modelField.stringValue = settings.model
        promptTextView.string = settings.prompt
        debounceField.integerValue = settings.debounceMilliseconds
        diagnosticButton.state = settings.diagnosticMode ? .on : .off
    }

    @objc private func resetPrompt() {
        promptTextView.string = AppSettings.defaultPrompt
    }

    @objc private func save() {
        let model = modelField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let prompt = promptTextView.string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !model.isEmpty, !prompt.isEmpty else {
            showAlert(message: "Model ID and custom prompt cannot be empty.")
            return
        }

        do {
            try KeychainStore.setAPIKey(
                apiKeyField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            settings.model = model
            settings.prompt = prompt
            settings.debounceMilliseconds = max(Int(debounceField.integerValue), 250)
            settings.diagnosticMode = diagnosticButton.state == .on
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
