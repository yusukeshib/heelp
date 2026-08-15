import Foundation

struct RuntimeOptions {
    static let current = RuntimeOptions(arguments: CommandLine.arguments)

    let diagnosticMode: Bool

    init(arguments: [String]) {
        diagnosticMode = arguments.contains("--diagnostic")
    }
}
