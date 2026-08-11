import Foundation

@MainActor
final class ReviewCoordinator {
    private let settings: AppSettings
    private let panel: SuggestionPanel
    private let triggerPanel: SelectionTriggerPanel
    private let client = ReviewClient()

    private var reviewTask: Task<Void, Never>?
    private var unavailableTask: Task<Void, Never>?
    private var revision = 0
    private var lastCaptureSignature: String?
    private var pendingCapture: CapturedText?
    private var lastRequestKey: String?
    private var cache: [String: ReviewResult] = [:]
    private var cacheOrder: [String] = []

    init(
        settings: AppSettings,
        panel: SuggestionPanel,
        triggerPanel: SelectionTriggerPanel
    ) {
        self.settings = settings
        self.panel = panel
        self.triggerPanel = triggerPanel
        panel.onClose = { [weak self] in
            self?.dismiss()
        }
        triggerPanel.onReview = { [weak self] in
            self?.reviewPendingSelection()
        }
    }

    func receive(_ capture: CapturedText) {
        unavailableTask?.cancel()
        unavailableTask = nil

        let text = reviewableText(from: capture.text)
        guard !text.isEmpty else {
            lastCaptureSignature = nil
            return
        }

        let anchor = capture.caretBounds
            .map { "\(Int($0.minX)),\(Int($0.minY))" } ?? ""
        let signature = [capture.applicationName ?? "", anchor, text].joined(separator: "\u{1F}")
        guard signature != lastCaptureSignature else { return }
        lastCaptureSignature = signature

        revision &+= 1
        reviewTask?.cancel()
        reviewTask = nil
        lastRequestKey = nil
        pendingCapture = CapturedText(
            text: text,
            caretBounds: capture.caretBounds,
            applicationName: capture.applicationName
        )
        panel.orderOut(nil)
        triggerPanel.show(near: capture.caretBounds)
    }

    func selectionCleared() {
        lastCaptureSignature = nil
        pendingCapture = nil
        triggerPanel.orderOut(nil)
    }

    func temporarilyUnavailable() {
        lastCaptureSignature = nil
        pendingCapture = nil
        triggerPanel.orderOut(nil)
        unavailableTask?.cancel()
        unavailableTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: 1_500_000_000)
                guard !Task.isCancelled else { return }
                self?.dismiss()
            } catch {
                // A new valid capture arrived before the grace period elapsed.
            }
        }
    }

    func dismiss() {
        revision &+= 1
        reviewTask?.cancel()
        reviewTask = nil
        unavailableTask?.cancel()
        unavailableTask = nil
        lastCaptureSignature = nil
        pendingCapture = nil
        lastRequestKey = nil
        triggerPanel.orderOut(nil)
        panel.orderOut(nil)
    }

    func reset() {
        dismiss()
        cache.removeAll()
        cacheOrder.removeAll()
    }

    private func reviewPendingSelection() {
        guard let capture = pendingCapture else { return }
        pendingCapture = nil
        triggerPanel.orderOut(nil)

        let currentRevision = revision
        panel.showLoading(near: capture.caretBounds)
        reviewTask = Task { [weak self] in
            await self?.review(text: capture.text, capture: capture, revision: currentRevision)
        }
    }

    private func review(text: String, capture: CapturedText, revision: Int) async {
        guard revision == self.revision else { return }

        if settings.diagnosticMode {
            let source = capture.applicationName.map { "Captured from \($0)" } ?? "Captured text"
            panel.show(
                result: ReviewResult(feedback: text, suggestion: ""),
                near: capture.caretBounds,
                heading: source
            )
            return
        }

        let provider = settings.provider
        let apiKey = KeychainStore.apiKey(for: provider)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !apiKey.isEmpty else {
            panel.show(
                result: ReviewResult(
                    feedback: "Open Jogen Settings and add a \(provider.displayName) API key.",
                    suggestion: ""
                ),
                near: capture.caretBounds
            )
            return
        }

        let requestKey = [provider.rawValue, settings.model, settings.prompt, text]
            .joined(separator: "\u{1F}")
        guard requestKey != lastRequestKey else { return }
        lastRequestKey = requestKey

        if let cached = cache[requestKey] {
            if cached.shouldDisplay {
                panel.show(result: cached, near: capture.caretBounds)
            } else {
                panel.orderOut(nil)
            }
            return
        }

        do {
            let result = try await client.review(
                text: text,
                applicationName: capture.applicationName,
                prompt: settings.prompt,
                provider: provider,
                model: settings.model,
                apiKey: apiKey
            )
            guard !Task.isCancelled,
                  revision == self.revision,
                  requestKey == lastRequestKey
            else { return }

            store(result, for: requestKey)
            guard result.shouldDisplay else {
                panel.orderOut(nil)
                return
            }
            panel.show(result: result, near: capture.caretBounds)
        } catch is CancellationError {
            return
        } catch {
            guard revision == self.revision else { return }
            lastRequestKey = nil
            panel.show(
                result: ReviewResult(
                    feedback: error.localizedDescription,
                    suggestion: ""
                ),
                near: capture.caretBounds,
                heading: "Jogen Error"
            )
        }
    }

    private func reviewableText(from value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        return String(trimmed.suffix(4_000))
    }

    private func store(_ result: ReviewResult, for key: String) {
        cache[key] = result
        cacheOrder.append(key)
        while cacheOrder.count > 50 {
            let oldest = cacheOrder.removeFirst()
            cache.removeValue(forKey: oldest)
        }
    }
}
