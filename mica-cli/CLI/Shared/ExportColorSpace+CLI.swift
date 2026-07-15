// ExportColorSpace+CLI.swift — CLI conformance for the shared color-space enum.
// The enum itself (raw values = the --color-space tokens, cgColorSpace bridge)
// lives in Models/IconSettings.swift, shared with the GUI.
import ArgumentParser

extension ExportColorSpace: ExpressibleByArgument {}
