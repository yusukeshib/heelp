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
    case invalidResponse(provider: String)
    case api(provider: String, status: Int, message: String)
    case emptyResponse(provider: String)
    case malformedOutput(provider: String, output: String)
    case stream(provider: String, message: String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse(let provider):
            return "\(provider) returned an invalid response."
        case .api(let provider, let status, let message):
            return "\(provider) error \(status): \(message)"
        case .emptyResponse(let provider):
            return "\(provider) returned no text."
        case .malformedOutput(let provider, _):
            return "\(provider) returned an unexpected response format."
        case .stream(let provider, let message):
            return "\(provider) stream error: \(message)"
        }
    }
}
