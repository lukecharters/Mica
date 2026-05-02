import ArgumentParser

@main
struct MicaCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "mica-cli",
        abstract: "Generate customized macOS app icons and extract icons from app bundles.",
        version: "1.1.0",
        subcommands: [IconGeneratorCommand.self, GetIconCommand.self],
        defaultSubcommand: IconGeneratorCommand.self
    )
}
