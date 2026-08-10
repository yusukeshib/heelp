import Foundation

enum AIProvider: String, CaseIterable, Codable, Hashable {
    case anthropic
    case openAI = "openai"
    case openRouter = "openrouter"

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
            return "gpt-4.1-mini"
        case .openRouter:
            return "anthropic/claude-haiku-4.5"
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
