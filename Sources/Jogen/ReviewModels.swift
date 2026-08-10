import CoreGraphics
import Foundation

struct CapturedText: Equatable {
    let text: String
    let caretBounds: CGRect?
    let applicationName: String?
}

struct ReviewResult: Codable, Equatable {
    let feedback: String
    let suggestion: String

    var hasSuggestion: Bool {
        !suggestion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

enum ReviewError: LocalizedError {
    case invalidURL
    case invalidResponse
    case api(status: Int, message: String)
    case emptyResponse
    case malformedOutput(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The Anthropic API URL is invalid."
        case .invalidResponse:
            return "Anthropic returned an invalid response."
        case .api(let status, let message):
            return "Anthropic error \(status): \(message)"
        case .emptyResponse:
            return "Anthropic returned no text."
        case .malformedOutput:
            return "Anthropic returned an unexpected response format."
        }
    }
}
