import Foundation

@MainActor
final class AppSettings {
    static let shared = AppSettings()

    static let defaultThinkingLevel = "none"

    private static let defaultPrompt = """
    Review the selected text and identify any grammatical errors.
    Suggest more natural phrasing where appropriate.
    Provide concise explanations and advice.
    If the text has no issues, state that briefly.
    Show nothing only when the selection is not suitable for proofreading, such as when it is not prose.
    """

    private static let translateToSpanishPrompt = """
    Translate the selected text into Spanish.
    Preserve the original meaning, tone, and formatting as closely as possible.
    Do not include explanations or a preamble. Set feedback to an empty string and put only the translated text in suggestion.
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
    }

    var provider: AIProvider {
        get {
            guard let value = defaults.string(forKey: Key.provider),
                  let provider = AIProvider(rawValue: value)
            else { return .openRouter }
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
                name: "Grammar correction",
                prompt: defaultPrompt
            ),
            PromptProfile(
                id: UUID(uuidString: "B80C363B-6C59-40B3-A52B-3505D42CB58E")!,
                name: "Translate to Spanish",
                prompt: translateToSpanishPrompt
            )
        ]
    }
}
