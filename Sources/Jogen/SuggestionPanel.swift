import AppKit

private final class CopyControl: NSView {
    var onClick: (() -> Void)?

    private let icon = NSImageView()
    private let label = NSTextField(labelWithString: "Copy suggestion")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.borderWidth = 1

        icon.image = NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: nil)
        icon.contentTintColor = .controlAccentColor
        icon.translatesAutoresizingMaskIntoConstraints = false

        label.font = .systemFont(ofSize: 11, weight: .semibold)
        label.textColor = .controlAccentColor

        let row = NSStackView(views: [icon, label])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 5
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)

        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            row.topAnchor.constraint(equalTo: topAnchor, constant: 5),
            row.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -5),
            icon.widthAnchor.constraint(equalToConstant: 13),
            icon.heightAnchor.constraint(equalToConstant: 13)
        ])
        updateColors()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        alphaValue = 0.65
        onClick?()
        DispatchQueue.main.async { [weak self] in self?.alphaValue = 1 }
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateColors()
    }

    func setTitle(_ value: String) {
        label.stringValue = value
    }

    private func updateColors() {
        layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.14).cgColor
        layer?.borderColor = NSColor.controlAccentColor.withAlphaComponent(0.55).cgColor
    }
}

@MainActor
final class SuggestionPanel: NSPanel {
    private let headingLabel = NSTextField(labelWithString: "Jogen")
    private let feedbackLabel = NSTextField(wrappingLabelWithString: "")
    private let suggestionLabel = NSTextField(wrappingLabelWithString: "")
    private let copyButton = CopyControl()
    private let stack = NSStackView()
    private var currentSuggestion = ""

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 120),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = true
        ignoresMouseEvents = false

        let effect = NSVisualEffectView()
        effect.material = .popover
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.wantsLayer = true
        effect.layer?.cornerRadius = 12
        effect.layer?.masksToBounds = true
        contentView = effect

        headingLabel.font = .systemFont(ofSize: 11, weight: .semibold)
        headingLabel.textColor = .secondaryLabelColor

        feedbackLabel.font = .systemFont(ofSize: 13)
        feedbackLabel.textColor = .labelColor
        feedbackLabel.maximumNumberOfLines = 8
        feedbackLabel.lineBreakMode = .byWordWrapping

        suggestionLabel.font = .systemFont(ofSize: 13, weight: .medium)
        suggestionLabel.textColor = .controlAccentColor
        suggestionLabel.maximumNumberOfLines = 6
        suggestionLabel.lineBreakMode = .byWordWrapping

        copyButton.onClick = { [weak self] in
            self?.copySuggestion()
        }
        copyButton.toolTip = "Copy the suggested text"

        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 7
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(headingLabel)
        stack.addArrangedSubview(feedbackLabel)
        stack.addArrangedSubview(suggestionLabel)
        stack.addArrangedSubview(copyButton)
        effect.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: effect.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: effect.trailingAnchor, constant: -14),
            stack.topAnchor.constraint(equalTo: effect.topAnchor, constant: 12),
            stack.bottomAnchor.constraint(equalTo: effect.bottomAnchor, constant: -12),
            feedbackLabel.widthAnchor.constraint(equalToConstant: 352),
            suggestionLabel.widthAnchor.constraint(equalToConstant: 352)
        ])
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    func show(result: ReviewResult, near accessibilityRect: CGRect?, heading: String = "Jogen") {
        headingLabel.stringValue = heading
        feedbackLabel.stringValue = result.feedback
        currentSuggestion = result.suggestion
        suggestionLabel.stringValue = result.hasSuggestion ? "→ \(result.suggestion)" : ""
        suggestionLabel.isHidden = !result.hasSuggestion
        copyButton.setTitle("Copy suggestion")
        copyButton.isHidden = !result.hasSuggestion

        contentView?.layoutSubtreeIfNeeded()
        let fittingHeight = stack.fittingSize.height + 24
        let panelSize = NSSize(width: 380, height: min(max(fittingHeight, 72), 320))
        setContentSize(panelSize)
        setFrameOrigin(origin(for: panelSize, near: accessibilityRect))
        orderFrontRegardless()
    }

    private func copySuggestion() {
        guard !currentSuggestion.isEmpty else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(currentSuggestion, forType: .string)
        copyButton.setTitle("Copied")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.copyButton.setTitle("Copy suggestion")
        }
    }

    private func origin(for panelSize: NSSize, near accessibilityRect: CGRect?) -> NSPoint {
        let anchor = accessibilityRect.map(convertFromAccessibilityCoordinates)
            ?? fallbackAnchor()
        let targetScreen = NSScreen.screens.first { $0.frame.intersects(anchor) }
            ?? NSScreen.main
        guard let visible = targetScreen?.visibleFrame else { return .zero }

        var x = anchor.minX
        var y = anchor.maxY + 8
        if y + panelSize.height > visible.maxY {
            y = anchor.minY - panelSize.height - 8
        }
        x = min(max(x, visible.minX + 8), visible.maxX - panelSize.width - 8)
        y = min(max(y, visible.minY + 8), visible.maxY - panelSize.height - 8)
        return NSPoint(x: x, y: y)
    }

    private func convertFromAccessibilityCoordinates(_ rect: CGRect) -> CGRect {
        let mainHeight = NSScreen.screens
            .first { $0.frame.origin == .zero }?
            .frame.height ?? NSScreen.main?.frame.height ?? 0
        return CGRect(
            x: rect.origin.x,
            y: mainHeight - rect.maxY,
            width: rect.width,
            height: rect.height
        )
    }

    private func fallbackAnchor() -> CGRect {
        guard let screen = NSScreen.main else { return .zero }
        return CGRect(
            x: screen.visibleFrame.midX,
            y: screen.visibleFrame.midY,
            width: 1,
            height: 1
        )
    }
}
