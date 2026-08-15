import AppKit

@MainActor
enum PanelPositioning {
    static func accessibilityRect(atAppKitPoint point: NSPoint) -> CGRect {
        CGRect(
            x: point.x,
            y: primaryScreenTop - point.y,
            width: 1,
            height: 1
        )
    }

    /// - Parameter reservedHeight: Height to test the above-the-anchor placement
    ///   against, instead of the current height. A streaming panel grows as text
    ///   arrives, and reserving its maximum height keeps that growth from
    ///   tipping the panel past the screen edge and flipping it below the anchor
    ///   mid-review.
    static func origin(
        for panelSize: NSSize,
        near accessibilityRect: CGRect?,
        gap: CGFloat,
        reservedHeight: CGFloat? = nil
    ) -> NSPoint {
        let anchor = accessibilityRect.map(appKitRect(fromAccessibility:))
            ?? fallbackAnchor()
        let targetScreen = NSScreen.screens.first { $0.frame.intersects(anchor) }
            ?? NSScreen.main
        guard let visible = targetScreen?.visibleFrame else { return .zero }

        var x = anchor.maxX
        var y = anchor.maxY + gap
        if y + max(reservedHeight ?? panelSize.height, panelSize.height) > visible.maxY {
            y = anchor.minY - panelSize.height - gap
        }

        let inset: CGFloat = 8
        x = min(max(x, visible.minX + inset), visible.maxX - panelSize.width - inset)
        y = min(max(y, visible.minY + inset), visible.maxY - panelSize.height - inset)
        return NSPoint(x: x, y: y)
    }

    private static var primaryScreenTop: CGFloat {
        NSScreen.screens.first { $0.frame.origin == .zero }?.frame.maxY
            ?? NSScreen.main?.frame.maxY
            ?? 0
    }

    private static func appKitRect(fromAccessibility rect: CGRect) -> CGRect {
        CGRect(
            x: rect.origin.x,
            y: primaryScreenTop - rect.maxY,
            width: rect.width,
            height: rect.height
        )
    }

    private static func fallbackAnchor() -> CGRect {
        guard let screen = NSScreen.main else { return .zero }
        return CGRect(
            x: screen.visibleFrame.midX,
            y: screen.visibleFrame.midY,
            width: 1,
            height: 1
        )
    }
}
