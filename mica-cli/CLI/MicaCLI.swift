import ArgumentParser
import Foundation

@main
struct MicaCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "mica-cli",
        abstract: "Generate customized macOS app icons and extract icons from app bundles.",
        version: CLIVersion.current,
        subcommands: [GenerateCommand.self, ExtractCommand.self],
        defaultSubcommand: GenerateCommand.self
    )

    static func main() async {
        let arguments = Array(CommandLine.arguments.dropFirst())
        if requestsGenerateHelp(arguments) {
            print(compactGenerateHelpMessage())
            return
        }
        await main(arguments)
    }

    private static func requestsGenerateHelp(_ arguments: [String]) -> Bool {
        guard arguments.contains("--help") || arguments.contains("-h") else {
            return false
        }
        if arguments.first == "generate" {
            return true
        }
        if arguments.first == "extract" || arguments == ["--help"] || arguments == ["-h"] {
            return false
        }
        return true
    }

    /// Compact the generated option table so each flag stays on one physical line.
    ///
    /// ArgumentParser uses a fixed 26-column label width. Long flag names therefore
    /// place even short descriptions on a second line. The wiki now carries the
    /// detailed reference, so the terminal help favours scanning.
    private static func compactGenerateHelpMessage() -> String {
        let continuationPrefix = String(repeating: " ", count: 26)
        var output: [String] = []
        var optionLine = false

        let help = helpMessage(for: GenerateCommand.self, columns: 200)
        for line in help.split(separator: "\n", omittingEmptySubsequences: false) {
            let text = String(line)
            if text.hasPrefix("  -") {
                output.append(text)
                optionLine = true
            } else if optionLine, text.hasPrefix(continuationPrefix), !output.isEmpty {
                output[output.count - 1] += "  " + text.trimmingCharacters(in: .whitespaces)
            } else {
                output.append(text)
                optionLine = false
            }
        }

        return output.joined(separator: "\n")
    }
}
