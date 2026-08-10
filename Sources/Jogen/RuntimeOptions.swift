import Foundation

struct RuntimeOptions {
    static let current = RuntimeOptions(arguments: CommandLine.arguments)

    static let defaultSelectionDelayMilliseconds = 300
    static let selectionDelayRange = 250...5_000

    let diagnosticMode: Bool
    let selectionDelayMilliseconds: Int

    init(arguments: [String]) {
        diagnosticMode = arguments.contains("--diagnostic")

        if let optionIndex = arguments.firstIndex(of: "--selection-delay-ms"),
           arguments.indices.contains(optionIndex + 1),
           let value = Int(arguments[optionIndex + 1]),
           Self.selectionDelayRange.contains(value) {
            selectionDelayMilliseconds = value
        } else {
            selectionDelayMilliseconds = Self.defaultSelectionDelayMilliseconds
        }
    }
}
