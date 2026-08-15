import Foundation

@MainActor
final class AppSettings {
    static let shared = AppSettings()

    static let defaultThinkingLevel = "none"

    private static let legacyDefaultsSuite = "com.yusukeshibata.jogen"

    private static let defaultPrompt = """
    選択された文章を確認し、文法上の間違いを指摘してください。
    より自然な表現があれば提案してください。
    説明と助言は日本語で、簡潔に表示してください。
    文章を確認して問題がない場合は、そのことを短く表示してください。
    選択内容が文章ではないなど、添削対象でない場合だけ何も表示しないでください。
    """

    private static let summarizePrompt = """
    選択された文章を日本語で簡潔に要約してください。
    重要な情報と結論を優先し、元の意味を変えないでください。
    説明や前置きは付けず、feedbackは空文字列にし、suggestionには要約本文だけを入れてください。
    """

    private enum Key {
        static let provider = "provider"
        static let model = "model"
        static let thinkingLevel = "thinkingLevel"
        static let promptProfiles = "promptProfiles"
        static let selectedPromptID = "selectedPromptID"
    }

    private let defaults: UserDefaults
    private let runtimeOptions: RuntimeOptions

    init(
        defaults: UserDefaults = .standard,
        runtimeOptions: RuntimeOptions = .current
    ) {
        self.defaults = defaults
        self.runtimeOptions = runtimeOptions
        migrateLegacySettingsIfNeeded()
    }

    private func migrateLegacySettingsIfNeeded() {
        guard let legacy = UserDefaults(suiteName: Self.legacyDefaultsSuite) else { return }

        let providerKeys = AIProvider.allCases.flatMap { provider in
            [modelKey(for: provider), thinkingLevelKey(for: provider)]
        }
        for key in [Key.provider] + providerKeys where defaults.object(forKey: key) == nil {
            guard let value = legacy.object(forKey: key) else { continue }
            defaults.set(value, forKey: key)
        }

        if defaults.data(forKey: Key.promptProfiles) == nil,
           let profiles = legacy.data(forKey: Key.promptProfiles) {
            defaults.set(profiles, forKey: Key.promptProfiles)
            if let selectedPromptID = legacy.string(forKey: Key.selectedPromptID) {
                defaults.set(selectedPromptID, forKey: Key.selectedPromptID)
            }
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

    var thinkingLevel: String {
        get { thinkingLevel(for: provider) }
        set { setThinkingLevel(newValue, for: provider) }
    }

    func thinkingLevel(for provider: AIProvider) -> String {
        defaults.string(forKey: thinkingLevelKey(for: provider)) ?? Self.defaultThinkingLevel
    }

    func setThinkingLevel(_ thinkingLevel: String, for provider: AIProvider) {
        defaults.set(thinkingLevel, forKey: thinkingLevelKey(for: provider))
    }

    private func thinkingLevelKey(for provider: AIProvider) -> String {
        "\(Key.thinkingLevel).\(provider.rawValue)"
    }

    var promptProfiles: [PromptProfile] {
        get {
            guard let data = defaults.data(forKey: Key.promptProfiles),
                  let profiles = try? JSONDecoder().decode([PromptProfile].self, from: data),
                  !profiles.isEmpty
            else { return Self.builtInProfiles }
            return profiles
        }
        set {
            guard !newValue.isEmpty,
                  let data = try? JSONEncoder().encode(newValue)
            else { return }
            defaults.set(data, forKey: Key.promptProfiles)
            let storedID = defaults.string(forKey: Key.selectedPromptID).flatMap(UUID.init(uuidString:))
            if storedID == nil || !newValue.contains(where: { $0.id == storedID }) {
                defaults.set(newValue[0].id.uuidString, forKey: Key.selectedPromptID)
            }
        }
    }

    var selectedPromptID: UUID {
        get {
            if let value = defaults.string(forKey: Key.selectedPromptID),
               let id = UUID(uuidString: value),
               promptProfiles.contains(where: { $0.id == id }) {
                return id
            }
            return promptProfiles[0].id
        }
        set {
            guard promptProfiles.contains(where: { $0.id == newValue }) else { return }
            defaults.set(newValue.uuidString, forKey: Key.selectedPromptID)
        }
    }

    var selectedPrompt: PromptProfile {
        promptProfiles.first(where: { $0.id == selectedPromptID }) ?? promptProfiles[0]
    }

    var prompt: String { selectedPrompt.prompt }

    var diagnosticMode: Bool { runtimeOptions.diagnosticMode }

    private static var builtInProfiles: [PromptProfile] {
        [
            PromptProfile(
                id: UUID(uuidString: "A93C242E-B65B-4DC6-86B1-3992D8F71F53")!,
                name: "Grammar correction in Japanese",
                prompt: defaultPrompt
            ),
            PromptProfile(
                id: UUID(uuidString: "B80C363B-6C59-40B3-A52B-3505D42CB58E")!,
                name: "Summarize in Japanese",
                prompt: summarizePrompt
            )
        ]
    }
}
