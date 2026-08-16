import Foundation

enum AIProvider: String, CaseIterable, Codable, Hashable {
    case openRouter = "openrouter"
    case openAI = "openai"
    case anthropic

    var displayName: String {
        switch self {
        case .anthropic:
            return "Anthropic"
        case .openAI:
            return "OpenAI"
        case .openRouter:
            return "OpenRouter"
        }
    }

    var defaultModel: String {
        switch self {
        case .anthropic:
            return "claude-haiku-4-5-20251001"
        case .openAI:
            return "gpt-5.6-luna"
        case .openRouter:
            return "openai/gpt-5.6-luna"
        }
    }

    var endpoint: URL {
        switch self {
        case .anthropic:
            return URL(string: "https://api.anthropic.com/v1/messages")!
        case .openAI:
            return URL(string: "https://api.openai.com/v1/chat/completions")!
        case .openRouter:
            return URL(string: "https://openrouter.ai/api/v1/chat/completions")!
        }
    }

    /// Reasoning models need room for both internal reasoning and visible output.
    /// A higher limit is also important for direct transformations such as translation.
    var maxOutputTokens: Int {
        switch self {
        case .anthropic, .openAI, .openRouter:
            return 2_000
        }
    }

    /// Newer OpenAI models reject `max_tokens` and require `max_completion_tokens`.
    /// OpenRouter normalizes `max_tokens` across all upstream models.
    var usesMaxCompletionTokens: Bool {
        switch self {
        case .openAI:
            return true
        case .anthropic, .openRouter:
            return false
        }
    }

    var supportsThinkingLevel: Bool {
        switch self {
        case .openAI, .openRouter:
            return true
        case .anthropic:
            return false
        }
    }

    /// OpenAI takes a flat `reasoning_effort`; OpenRouter normalizes the same
    /// control under a nested `reasoning` object.
    var usesNestedReasoningParameter: Bool {
        switch self {
        case .openRouter:
            return true
        case .anthropic, .openAI:
            return false
        }
    }

    var keychainAccount: String {
        switch self {
        case .anthropic:
            return "anthropic-api-key"
        case .openAI:
            return "openai-api-key"
        case .openRouter:
            return "openrouter-api-key"
        }
    }

    var apiKeyPlaceholder: String {
        switch self {
        case .anthropic:
            return "sk-ant-…"
        case .openAI:
            return "sk-…"
        case .openRouter:
            return "sk-or-…"
        }
    }
}
