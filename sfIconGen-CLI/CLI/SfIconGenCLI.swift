import ArgumentParser

@main
struct SfIconGenCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "sfIconGen-CLI",
        abstract: "Generate customized macOS app icons and extract icons from app bundles.",
        version: "1.1.0",
        subcommands: [IconGeneratorCommand.self, GetIconCommand.self],
        defaultSubcommand: IconGeneratorCommand.self
    )
}
