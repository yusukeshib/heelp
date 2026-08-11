import AppKit

private final class ReviewButton: NSButton {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

@MainActor
final class SelectionTriggerPanel: NSPanel {
    var onReview: (() -> Void)?

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 88, height: 34),
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

        let effect = NSVisualEffectView()
        effect.material = .popover
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.wantsLayer = true
        effect.layer?.cornerRadius = 9
        effect.layer?.masksToBounds = true
        contentView = effect

        let button = ReviewButton(title: "Jogen", target: self, action: #selector(reviewSelection))
        button.bezelStyle = .recessed
        button.isBordered = false
        button.font = .systemFont(ofSize: 12, weight: .semibold)
        button.image = NSImage(systemSymbolName: "text.bubble", accessibilityDescription: nil)
        button.imagePosition = .imageLeading
        button.contentTintColor = .controlAccentColor
        button.toolTip = "Review this selection with Jogen"
        button.translatesAutoresizingMaskIntoConstraints = false
        effect.addSubview(button)

        NSLayoutConstraint.activate([
            button.leadingAnchor.constraint(equalTo: effect.leadingAnchor, constant: 8),
            button.trailingAnchor.constraint(equalTo: effect.trailingAnchor, constant: -8),
            button.topAnchor.constraint(equalTo: effect.topAnchor, constant: 5),
            button.bottomAnchor.constraint(equalTo: effect.bottomAnchor, constant: -5)
        ])
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    func show(near accessibilityRect: CGRect?) {
        let panelSize = NSSize(width: 88, height: 34)
        setContentSize(panelSize)
        setFrameOrigin(origin(for: panelSize, near: accessibilityRect))
        orderFrontRegardless()
    }

    @objc private func reviewSelection() {
        onReview?()
    }

    private func origin(for panelSize: NSSize, near accessibilityRect: CGRect?) -> NSPoint {
        let anchor = accessibilityRect.map(convertFromAccessibilityCoordinates)
            ?? fallbackAnchor()
        let targetScreen = NSScreen.screens.first { $0.frame.intersects(anchor) }
            ?? NSScreen.main
        guard let visible = targetScreen?.visibleFrame else { return .zero }

        var x = anchor.minX
        var y = anchor.maxY + 6
        if y + panelSize.height > visible.maxY {
            y = anchor.minY - panelSize.height - 6
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
