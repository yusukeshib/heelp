import Foundation

@MainActor
final class AppSettings {
    static let shared = AppSettings()

    static let defaultModel = AIProvider.anthropic.defaultModel
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
        static let provider = "provider"
        static let model = "model"
        static let prompt = "prompt"
    }

    private let defaults: UserDefaults
    private let runtimeOptions: RuntimeOptions

    init(
        defaults: UserDefaults = .standard,
        runtimeOptions: RuntimeOptions = .current
    ) {
        self.defaults = defaults
        self.runtimeOptions = runtimeOptions
        if defaults.string(forKey: Key.model) == Self.retiredDefaultModel {
            defaults.set(Self.defaultModel, forKey: Key.model)
        }
        if let prompt = defaults.string(forKey: Key.prompt),
           prompt == Self.retiredDefaultPrompt ||
            prompt == Self.retiredTypingPrompt ||
            prompt == Self.retiredSelectionSilencePrompt {
            defaults.set(Self.defaultPrompt, forKey: Key.prompt)
        }
    }

    var provider: AIProvider {
        get {
            guard let value = defaults.string(forKey: Key.provider),
                  let provider = AIProvider(rawValue: value)
            else { return .anthropic }
            return provider
        }
        set { defaults.set(newValue.rawValue, forKey: Key.provider) }
    }

    var model: String {
        get { model(for: provider) }
        set { setModel(newValue, for: provider) }
    }

    func model(for provider: AIProvider) -> String {
        defaults.string(forKey: modelKey(for: provider)) ?? provider.defaultModel
    }

    func setModel(_ model: String, for provider: AIProvider) {
        defaults.set(model, forKey: modelKey(for: provider))
    }

    private func modelKey(for provider: AIProvider) -> String {
        switch provider {
        case .anthropic:
            return Key.model
        case .openAI, .openRouter:
            return "\(Key.model).\(provider.rawValue)"
        }
    }

    var prompt: String {
        get { defaults.string(forKey: Key.prompt) ?? Self.defaultPrompt }
        set { defaults.set(newValue, forKey: Key.prompt) }
    }

    var selectionDelayMilliseconds: Int {
        runtimeOptions.selectionDelayMilliseconds
    }

    var diagnosticMode: Bool {
        runtimeOptions.diagnosticMode
    }

    func resetPrompt() {
        defaults.removeObject(forKey: Key.prompt)
    }
}
