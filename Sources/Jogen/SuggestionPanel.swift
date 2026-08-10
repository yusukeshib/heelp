import AppKit

private final class FlippedStackView: NSStackView {
    override var isFlipped: Bool { true }
}

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
    var onClose: (() -> Void)?

    private let headingLabel = NSTextField(labelWithString: "Jogen")
    private let feedbackLabel = NSTextField(wrappingLabelWithString: "")
    private let suggestionLabel = NSTextField(wrappingLabelWithString: "")
    private let progressIndicator = NSProgressIndicator()
    private let progressLabel = NSTextField(labelWithString: "Reviewing selection…")
    private let progressRow = NSStackView()
    private let closeButton = NSButton()
    private let copyButton = CopyControl()
    private let bodyScrollView = NSScrollView()
    private let bodyStack = FlippedStackView()
    private let stack = NSStackView()
    private var bodyHeightConstraint: NSLayoutConstraint!
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

        closeButton.image = NSImage(
            systemSymbolName: "xmark.circle.fill",
            accessibilityDescription: "Close"
        )
        closeButton.imagePosition = .imageOnly
        closeButton.imageScaling = .scaleProportionallyDown
        closeButton.contentTintColor = .tertiaryLabelColor
        closeButton.isBordered = false
        closeButton.target = self
        closeButton.action = #selector(closePanel)
        closeButton.toolTip = "Close"
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.setContentHuggingPriority(.required, for: .horizontal)

        progressIndicator.style = .spinning
        progressIndicator.controlSize = .small
        progressIndicator.isIndeterminate = true
        progressIndicator.translatesAutoresizingMaskIntoConstraints = false

        progressLabel.font = .systemFont(ofSize: 12)
        progressLabel.textColor = .secondaryLabelColor

        progressRow.orientation = .horizontal
        progressRow.alignment = .centerY
        progressRow.spacing = 7
        progressRow.addArrangedSubview(progressIndicator)
        progressRow.addArrangedSubview(progressLabel)
        progressRow.isHidden = true

        feedbackLabel.font = .systemFont(ofSize: 13)
        feedbackLabel.textColor = .labelColor
        feedbackLabel.maximumNumberOfLines = 0
        feedbackLabel.lineBreakMode = .byWordWrapping

        suggestionLabel.font = .systemFont(ofSize: 13, weight: .medium)
        suggestionLabel.textColor = .controlAccentColor
        suggestionLabel.maximumNumberOfLines = 0
        suggestionLabel.lineBreakMode = .byWordWrapping

        copyButton.onClick = { [weak self] in
            self?.copySuggestion()
        }
        copyButton.toolTip = "Copy the suggested text"

        let headerRow = NSStackView(views: [headingLabel, NSView(), closeButton])
        headerRow.orientation = .horizontal
        headerRow.alignment = .centerY
        headerRow.spacing = 6

        bodyStack.orientation = .vertical
        bodyStack.alignment = .leading
        bodyStack.spacing = 7
        bodyStack.addArrangedSubview(progressRow)
        bodyStack.addArrangedSubview(feedbackLabel)
        bodyStack.addArrangedSubview(suggestionLabel)
        bodyStack.addArrangedSubview(copyButton)
        bodyStack.frame = NSRect(x: 0, y: 0, width: 352, height: 18)

        bodyScrollView.borderType = .noBorder
        bodyScrollView.drawsBackground = false
        bodyScrollView.hasVerticalScroller = true
        bodyScrollView.hasHorizontalScroller = false
        bodyScrollView.autohidesScrollers = true
        bodyScrollView.scrollerStyle = .overlay
        bodyScrollView.documentView = bodyStack
        bodyScrollView.translatesAutoresizingMaskIntoConstraints = false

        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 7
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(headerRow)
        stack.addArrangedSubview(bodyScrollView)
        effect.addSubview(stack)

        bodyHeightConstraint = bodyScrollView.heightAnchor.constraint(equalToConstant: 18)
        bodyHeightConstraint.isActive = true

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: effect.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: effect.trailingAnchor, constant: -14),
            stack.topAnchor.constraint(equalTo: effect.topAnchor, constant: 12),
            stack.bottomAnchor.constraint(equalTo: effect.bottomAnchor, constant: -12),
            headerRow.widthAnchor.constraint(equalToConstant: 352),
            bodyScrollView.widthAnchor.constraint(equalToConstant: 352),
            closeButton.widthAnchor.constraint(equalToConstant: 16),
            closeButton.heightAnchor.constraint(equalToConstant: 16),
            progressIndicator.widthAnchor.constraint(equalToConstant: 14),
            progressIndicator.heightAnchor.constraint(equalToConstant: 14),
            feedbackLabel.widthAnchor.constraint(equalToConstant: 352),
            suggestionLabel.widthAnchor.constraint(equalToConstant: 352)
        ])
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    func show(result: ReviewResult, near accessibilityRect: CGRect?, heading: String = "Jogen") {
        progressIndicator.stopAnimation(nil)
        progressRow.isHidden = true
        headingLabel.stringValue = heading
        feedbackLabel.stringValue = result.feedback
        feedbackLabel.isHidden = false
        currentSuggestion = result.suggestion
        suggestionLabel.stringValue = result.hasSuggestion ? "→ \(result.suggestion)" : ""
        suggestionLabel.isHidden = !result.hasSuggestion
        copyButton.setTitle("Copy suggestion")
        copyButton.isHidden = !result.hasSuggestion
        present(near: accessibilityRect)
    }

    func showLoading(near accessibilityRect: CGRect?) {
        headingLabel.stringValue = "Jogen"
        feedbackLabel.isHidden = true
        suggestionLabel.isHidden = true
        copyButton.isHidden = true
        currentSuggestion = ""
        progressRow.isHidden = false
        progressIndicator.startAnimation(nil)
        present(near: accessibilityRect)
    }

    private func present(near accessibilityRect: CGRect?) {
        bodyStack.setFrameSize(NSSize(width: 352, height: 18))
        bodyStack.layoutSubtreeIfNeeded()
        let bodyHeight = max(bodyStack.fittingSize.height, 18)
        bodyStack.setFrameSize(NSSize(width: 352, height: bodyHeight))
        bodyHeightConstraint.constant = min(bodyHeight, 400)
        bodyScrollView.contentView.scroll(to: .zero)
        bodyScrollView.reflectScrolledClipView(bodyScrollView.contentView)

        contentView?.layoutSubtreeIfNeeded()
        let fittingHeight = stack.fittingSize.height + 24
        let panelSize = NSSize(width: 380, height: min(max(fittingHeight, 72), 460))
        setContentSize(panelSize)
        setFrameOrigin(origin(for: panelSize, near: accessibilityRect))
        orderFrontRegardless()
    }

    @objc private func closePanel() {
        progressIndicator.stopAnimation(nil)
        if let onClose {
            onClose()
        } else {
            orderOut(nil)
        }
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
