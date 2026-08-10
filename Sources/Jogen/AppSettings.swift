import Foundation

@MainActor
final class AppSettings {
    static let shared = AppSettings()

    static let defaultModel = "claude-haiku-4-5-20251001"
    private static let retiredDefaultModel = "claude-3-5-haiku-20241022"

    private static let retiredDefaultPrompt = """
    入力中の文章を確認し、文法上の間違いを指摘してください。
    より自然な表現があれば提案してください。
    説明と助言は日本語で、簡潔に表示してください。
    問題がない場合は、そのことを短く伝えてください。
    """

    private static let retiredTypingPrompt = """
    入力中の文章を確認し、文法上の間違いを指摘してください。
    より自然な表現があれば提案してください。
    説明と助言は日本語で、簡潔に表示してください。
    ユーザーにとって有用で具体的な助言がある場合だけ表示してください。
    助言する必要がない場合は、確認メッセージも含めて何も表示しないでください。
    """

    private static let retiredSelectionSilencePrompt = """
    選択された文章を確認し、文法上の間違いを指摘してください。
    より自然な表現があれば提案してください。
    説明と助言は日本語で、簡潔に表示してください。
    ユーザーにとって有用で具体的な助言がある場合だけ表示してください。
    助言する必要がない場合は、確認メッセージも含めて何も表示しないでください。
    """

    static let defaultPrompt = """
    選択された文章を確認し、文法上の間違いを指摘してください。
    より自然な表現があれば提案してください。
    説明と助言は日本語で、簡潔に表示してください。
    文章を確認して問題がない場合は、そのことを短く表示してください。
    選択内容が文章ではないなど、添削対象でない場合だけ何も表示しないでください。
    """

    private enum Key {
        static let model = "model"
        static let prompt = "prompt"
        static let debounceMilliseconds = "debounceMilliseconds"
        static let diagnosticMode = "diagnosticMode"
        static let didMigrateToSelectionMode = "didMigrateToSelectionMode"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if defaults.string(forKey: Key.model) == Self.retiredDefaultModel {
            defaults.set(Self.defaultModel, forKey: Key.model)
        }
        if let prompt = defaults.string(forKey: Key.prompt),
           prompt == Self.retiredDefaultPrompt ||
            prompt == Self.retiredTypingPrompt ||
            prompt == Self.retiredSelectionSilencePrompt {
            defaults.set(Self.defaultPrompt, forKey: Key.prompt)
        }
        if !defaults.bool(forKey: Key.didMigrateToSelectionMode) {
            if defaults.object(forKey: Key.debounceMilliseconds) == nil ||
                defaults.integer(forKey: Key.debounceMilliseconds) == 700 {
                defaults.set(300, forKey: Key.debounceMilliseconds)
            }
            defaults.set(true, forKey: Key.didMigrateToSelectionMode)
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
            guard defaults.object(forKey: Key.debounceMilliseconds) != nil else { return 300 }
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
