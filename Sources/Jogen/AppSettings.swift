import Foundation

@MainActor
final class AppSettings {
    static let shared = AppSettings()

    static let defaultModel = AIProvider.anthropic.defaultModel
    private static let retiredDefaultModel = "claude-3-5-haiku-20241022"

    static let defaultPrompt = """
    選択された文章を確認し、文法上の間違いを指摘してください。
    より自然な表現があれば提案してください。
    説明と助言は日本語で、簡潔に表示してください。
    文章を確認して問題がない場合は、そのことを短く表示してください。
    選択内容が文章ではないなど、添削対象でない場合だけ何も表示しないでください。
    """

    static let summarizePrompt = """
    選択された文章を日本語で簡潔に要約してください。
    重要な情報と結論を優先し、元の意味を変えないでください。
    feedbackには要約についての短い説明を、suggestionには要約本文だけを入れてください。
    """

    private enum Key {
        static let provider = "provider"
        static let model = "model"
        static let prompt = "prompt"
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
        if defaults.string(forKey: Key.model) == Self.retiredDefaultModel {
            defaults.set(Self.defaultModel, forKey: Key.model)
        }
        migratePromptProfilesIfNeeded()
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

    private func migratePromptProfilesIfNeeded() {
        guard defaults.data(forKey: Key.promptProfiles) == nil else { return }
        var profiles = Self.builtInProfiles
        if let legacyPrompt = defaults.string(forKey: Key.prompt),
           !legacyPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           legacyPrompt != Self.defaultPrompt {
            profiles[0].prompt = legacyPrompt
        }
        guard let data = try? JSONEncoder().encode(profiles) else { return }
        defaults.set(data, forKey: Key.promptProfiles)
        defaults.set(profiles[0].id.uuidString, forKey: Key.selectedPromptID)
        defaults.removeObject(forKey: Key.prompt)
    }
}
