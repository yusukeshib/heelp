import CoreGraphics
import Foundation

struct CapturedText: Equatable {
    let text: String
    let caretBounds: CGRect?
    let applicationName: String?
}

struct ReviewResult: Codable, Equatable {
    let show: Bool
    let feedback: String
    let suggestion: String

    init(show: Bool = true, feedback: String, suggestion: String) {
        self.show = show
        self.feedback = feedback
        self.suggestion = suggestion
    }

    private enum CodingKeys: String, CodingKey {
        case show
        case feedback
        case suggestion
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        show = try container.decodeIfPresent(Bool.self, forKey: .show) ?? true
        feedback = try container.decodeIfPresent(String.self, forKey: .feedback) ?? ""
        suggestion = try container.decodeIfPresent(String.self, forKey: .suggestion) ?? ""
    }

    var hasSuggestion: Bool {
        !suggestion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var shouldDisplay: Bool {
        show && (!feedback.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || hasSuggestion)
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
