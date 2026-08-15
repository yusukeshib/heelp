import Foundation

/// A `ReviewResult` that has not finished arriving.
///
/// Partials exist only to draw intermediate frames while a response streams in.
/// The result the user ends up with is always decoded from the complete buffer
/// by the same strict decoder used before streaming existed, so a mistake in the
/// tolerant parsing below can never corrupt the final review.
struct PartialReview: Equatable {
    var show: Bool?
    var feedback: String
    var suggestion: String

    var hasContent: Bool {
        !feedback.isEmpty || !suggestion.isEmpty
    }
}

enum ReviewStreamEvent {
    case partial(PartialReview)
    case final(ReviewResult)
}

/// Extracts values from the JSON object the model is still writing.
///
/// The prompt fixes the key order as `show`, `feedback`, `suggestion`, so `show`
/// settles almost immediately and the long `suggestion` lands last. Keys are
/// therefore searched for in that order and each search starts where the previous
/// value ended, which stops a `"suggestion"` mention inside `feedback` from being
/// mistaken for the real key. A model that reorders the keys degrades to an empty
/// partial rather than a wrong one.
///
/// Rescanning the whole buffer per chunk is quadratic, but the buffer is bounded
/// by the size of a review, so the cost is nothing next to network latency.
struct StreamingReviewParser {
    private(set) var raw = ""

    mutating func append(_ chunk: String) {
        raw.append(chunk)
    }

    var partial: PartialReview {
        var cursor = raw.startIndex
        return PartialReview(
            show: bool(forKey: "show", from: &cursor),
            feedback: string(forKey: "feedback", from: &cursor),
            suggestion: string(forKey: "suggestion", from: &cursor)
        )
    }

    /// Advances `cursor` past `"key":` and returns the first index of its value,
    /// or nil while the key and its colon are still in flight.
    private func valueStart(forKey key: String, from cursor: inout String.Index) -> String.Index? {
        guard let keyRange = raw.range(of: "\"\(key)\"", range: cursor..<raw.endIndex) else {
            return nil
        }

        var index = keyRange.upperBound
        while index < raw.endIndex, raw[index].isWhitespace {
            index = raw.index(after: index)
        }
        guard index < raw.endIndex, raw[index] == ":" else { return nil }
        index = raw.index(after: index)
        while index < raw.endIndex, raw[index].isWhitespace {
            index = raw.index(after: index)
        }
        guard index < raw.endIndex else { return nil }

        cursor = index
        return index
    }

    private func bool(forKey key: String, from cursor: inout String.Index) -> Bool? {
        guard let start = valueStart(forKey: key, from: &cursor) else { return nil }
        let rest = raw[start...]
        if rest.hasPrefix("true") {
            cursor = raw.index(start, offsetBy: 4, limitedBy: raw.endIndex) ?? raw.endIndex
            return true
        }
        if rest.hasPrefix("false") {
            cursor = raw.index(start, offsetBy: 5, limitedBy: raw.endIndex) ?? raw.endIndex
            return false
        }
        return nil
    }

    private func string(forKey key: String, from cursor: inout String.Index) -> String {
        guard let start = valueStart(forKey: key, from: &cursor), raw[start] == "\"" else {
            return ""
        }

        // Locate the closing quote, skipping escaped ones. Without a closing
        // quote the value is still streaming, so everything received counts.
        let bodyStart = raw.index(after: start)
        var index = bodyStart
        var end = raw.endIndex
        var isEscaped = false
        while index < raw.endIndex {
            let character = raw[index]
            if isEscaped {
                isEscaped = false
            } else if character == "\\" {
                isEscaped = true
            } else if character == "\"" {
                end = index
                break
            }
            index = raw.index(after: index)
        }

        cursor = end < raw.endIndex ? raw.index(after: end) : raw.endIndex
        return decodeJSONString(raw[bodyStart..<end])
    }

    /// Re-decodes a raw JSON string body by handing it back to `JSONDecoder`, so
    /// escapes and surrogate pairs behave exactly as they will in the final
    /// strict decode instead of being reimplemented by hand.
    private func decodeJSONString(_ body: Substring) -> String {
        var value = String(body)

        // An escape whose payload has not arrived is invalid JSON on its own.
        // Drop the incomplete tail; the next chunk brings it back.
        let trailingBackslashes = value.reversed().prefix { $0 == "\\" }.count
        if !trailingBackslashes.isMultiple(of: 2) {
            value.removeLast()
        }
        if let partialEscape = value.range(
            of: "\\\\u[0-9a-fA-F]{0,3}$",
            options: .regularExpression
        ) {
            value.removeSubrange(partialEscape)
        }

        if let decoded = decodeQuoted(value) { return decoded }

        // A high surrogate is invalid until its pair lands, so wait for it.
        if let lastEscape = value.range(
            of: "\\\\u[0-9a-fA-F]{4}$",
            options: .regularExpression
        ) {
            value.removeSubrange(lastEscape)
            if let decoded = decodeQuoted(value) { return decoded }
        }
        return ""
    }

    private func decodeQuoted(_ value: String) -> String? {
        guard let data = "\"\(value)\"".data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(String.self, from: data)
    }
}
