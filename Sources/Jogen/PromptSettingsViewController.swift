import AppKit

@MainActor
final class PromptSettingsViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    var onSave: (() -> Void)?
    var onCancel: (() -> Void)?

    private let settings: AppSettings
    private let tableView = NSTableView()
    private let nameField = NSTextField()
    private let promptTextView = NSTextView()
    private let deleteButton = NSButton(title: "−", target: nil, action: nil)
    private var drafts: [PromptProfile] = []
    private var displayedID: UUID?

    init(settings: AppSettings) {
        self.settings = settings
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        let content = NSView()
        view = content
        buildUI(in: content)
    }

    func loadValues() {
        displayedID = nil
        drafts = settings.promptProfiles
        tableView.reloadData()
        let selectedIndex = drafts.firstIndex(where: { $0.id == settings.selectedPromptID }) ?? 0
        selectDraft(at: selectedIndex)
    }

    private func buildUI(in content: NSView) {
        let subtitle = NSTextField(
            wrappingLabelWithString: "Create prompts and select the active one from the Jogen menu."
        )
        subtitle.textColor = .secondaryLabelColor

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("PromptName"))
        column.title = "Prompts"
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.dataSource = self
        tableView.delegate = self
        tableView.allowsEmptySelection = false
        tableView.usesAlternatingRowBackgroundColors = true

        let tableScroll = NSScrollView()
        tableScroll.borderType = .bezelBorder
        tableScroll.hasVerticalScroller = true
        tableScroll.documentView = tableView

        let addButton = NSButton(title: "+", target: self, action: #selector(addPrompt))
        addButton.toolTip = "Add Prompt"
        deleteButton.target = self
        deleteButton.action = #selector(deletePrompt)
        deleteButton.toolTip = "Delete Prompt"
        for button in [addButton, deleteButton] {
            button.bezelStyle = .smallSquare
            button.font = .systemFont(ofSize: 15)
            button.widthAnchor.constraint(equalToConstant: 30).isActive = true
        }

        let listControls = NSStackView(views: [addButton, deleteButton, NSView()])
        listControls.orientation = .horizontal
        listControls.alignment = .centerY
        listControls.spacing = 4

        let listPane = NSStackView(views: [label("PROMPTS"), tableScroll, listControls])
        listPane.orientation = .vertical
        listPane.alignment = .leading
        listPane.spacing = 6
        listPane.translatesAutoresizingMaskIntoConstraints = false
        tableScroll.widthAnchor.constraint(equalTo: listPane.widthAnchor).isActive = true
        listControls.widthAnchor.constraint(equalTo: listPane.widthAnchor).isActive = true
        listPane.widthAnchor.constraint(equalToConstant: 205).isActive = true

        nameField.placeholderString = "Prompt name"

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

        let cancelButton = NSButton(title: "Cancel", target: self, action: #selector(cancel))
        let updateButton = NSButton(title: "Update", target: self, action: #selector(update))
        updateButton.keyEquivalent = "\r"
        let buttonRow = NSStackView(views: [NSView(), cancelButton, updateButton])
        buttonRow.orientation = .horizontal
        buttonRow.alignment = .centerY
        buttonRow.spacing = 8

        let editorPane = NSStackView(views: [
            label("NAME"),
            nameField,
            label("INSTRUCTIONS"),
            promptScroll,
            buttonRow
        ])
        editorPane.orientation = .vertical
        editorPane.alignment = .leading
        editorPane.spacing = 7
        editorPane.translatesAutoresizingMaskIntoConstraints = false
        nameField.widthAnchor.constraint(equalTo: editorPane.widthAnchor).isActive = true
        promptScroll.widthAnchor.constraint(equalTo: editorPane.widthAnchor).isActive = true
        buttonRow.widthAnchor.constraint(equalTo: editorPane.widthAnchor).isActive = true

        let panes = NSStackView(views: [listPane, editorPane])
        panes.orientation = .horizontal
        panes.alignment = .top
        panes.spacing = 18
        panes.distribution = .fill
        panes.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView(views: [subtitle, panes])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -16),
            subtitle.widthAnchor.constraint(equalTo: stack.widthAnchor),
            panes.widthAnchor.constraint(equalTo: stack.widthAnchor),
            panes.bottomAnchor.constraint(equalTo: stack.bottomAnchor),
            listPane.heightAnchor.constraint(equalTo: panes.heightAnchor),
            editorPane.heightAnchor.constraint(equalTo: panes.heightAnchor)
        ])
    }

    private func label(_ value: String) -> NSTextField {
        let field = NSTextField(labelWithString: value)
        field.font = .systemFont(ofSize: 11, weight: .semibold)
        field.textColor = .secondaryLabelColor
        return field
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        drafts.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let identifier = NSUserInterfaceItemIdentifier("PromptCell")
        let cell = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView
            ?? NSTableCellView()
        cell.identifier = identifier
        if cell.textField == nil {
            let textField = NSTextField(labelWithString: "")
            textField.translatesAutoresizingMaskIntoConstraints = false
            textField.lineBreakMode = .byTruncatingTail
            cell.addSubview(textField)
            cell.textField = textField
            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 5),
                textField.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -5),
                textField.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
            ])
        }
        cell.textField?.stringValue = drafts[row].name
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        captureDisplayedDraft()
        showDraft(at: tableView.selectedRow)
    }

    private func selectDraft(at index: Int) {
        guard drafts.indices.contains(index) else { return }
        tableView.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
        tableView.scrollRowToVisible(index)
        showDraft(at: index)
    }

    private func captureDisplayedDraft() {
        guard let displayedID,
              let index = drafts.firstIndex(where: { $0.id == displayedID })
        else { return }
        drafts[index].name = nameField.stringValue
        drafts[index].prompt = promptTextView.string
        tableView.reloadData(forRowIndexes: IndexSet(integer: index), columnIndexes: IndexSet(integer: 0))
    }

    private func showDraft(at index: Int) {
        guard drafts.indices.contains(index) else { return }
        displayedID = drafts[index].id
        nameField.stringValue = drafts[index].name
        promptTextView.string = drafts[index].prompt
        deleteButton.isEnabled = drafts.count > 1
    }

    @objc private func addPrompt() {
        captureDisplayedDraft()
        let profile = PromptProfile(name: "New Prompt", prompt: "")
        drafts.append(profile)
        tableView.reloadData()
        selectDraft(at: drafts.count - 1)
        nameField.selectText(nil)
    }

    @objc private func deletePrompt() {
        guard drafts.count > 1,
              let displayedID,
              let index = drafts.firstIndex(where: { $0.id == displayedID })
        else { return }
        drafts.remove(at: index)
        tableView.reloadData()
        selectDraft(at: min(index, drafts.count - 1))
    }

    @objc private func cancel() {
        onCancel?()
    }

    @objc private func update() {
        captureDisplayedDraft()
        for index in drafts.indices {
            drafts[index].name = drafts[index].name.trimmingCharacters(in: .whitespacesAndNewlines)
            drafts[index].prompt = drafts[index].prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard drafts.allSatisfy({ !$0.name.isEmpty && !$0.prompt.isEmpty }) else {
            showAlert(message: "Prompt names and instructions cannot be empty.")
            return
        }
        settings.promptProfiles = drafts
        onSave?()
    }

    private func showAlert(message: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Could not update prompts"
        alert.informativeText = message
        guard let window = view.window else { return }
        alert.beginSheetModal(for: window)
    }
}
