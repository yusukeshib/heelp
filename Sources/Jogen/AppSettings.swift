import Foundation

@MainActor
final class AppSettings {
    static let shared = AppSettings()

    static let defaultModel = "claude-haiku-4-5-20251001"
    private static let retiredDefaultModel = "claude-3-5-haiku-20241022"

    static let defaultPrompt = """
    入力中の文章を確認し、文法上の間違いを指摘してください。
    より自然な表現があれば提案してください。
    説明と助言は日本語で、簡潔に表示してください。
    問題がない場合は、そのことを短く伝えてください。
    """

    private enum Key {
        static let model = "model"
        static let prompt = "prompt"
        static let debounceMilliseconds = "debounceMilliseconds"
        static let diagnosticMode = "diagnosticMode"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if defaults.string(forKey: Key.model) == Self.retiredDefaultModel {
            defaults.set(Self.defaultModel, forKey: Key.model)
        }
    }

    var model: String {
        get { defaults.string(forKey: Key.model) ?? Self.defaultModel }
        set { defaults.set(newValue, forKey: Key.model) }
    }

    var prompt: String {
        get { defaults.string(forKey: Key.prompt) ?? Self.defaultPrompt }
        set { defaults.set(newValue, forKey: Key.prompt) }
    }

    var debounceMilliseconds: Int {
        get {
            guard defaults.object(forKey: Key.debounceMilliseconds) != nil else { return 700 }
            return min(max(defaults.integer(forKey: Key.debounceMilliseconds), 250), 5_000)
        }
        set { defaults.set(min(max(newValue, 250), 5_000), forKey: Key.debounceMilliseconds) }
    }

    var diagnosticMode: Bool {
        get { defaults.bool(forKey: Key.diagnosticMode) }
        set { defaults.set(newValue, forKey: Key.diagnosticMode) }
    }

    func resetPrompt() {
        defaults.removeObject(forKey: Key.prompt)
    }
}
