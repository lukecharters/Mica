// CLI/Support/SharedTokens+CLI.swift
import ArgumentParser

// `ToggleState` lives in Mica/Services/SettingsTokens.swift so the configuration
// codec shares it with the flags; only the ArgumentParser conformance is
// CLI-specific. String-RawRepresentable supplies both `init?(argument:)` and the
// help text's value list.
extension ToggleState: ExpressibleByArgument {}
