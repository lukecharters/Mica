import ArgumentParser
import Foundation

// MARK: - Standard error

/// A stateless `TextOutputStream` that writes to standard error, so diagnostics
/// can be kept off stdout (which carries the machine-readable result). A fresh
/// instance is created per write — it holds no state — which keeps it free of
/// the global mutable shared state Swift 6 concurrency checking rejects.
struct StandardErrorStream: TextOutputStream {
    mutating func write(_ string: String) {
        FileHandle.standardError.write(Data(string.utf8))
    }
}

/// Print a line to standard error.
func printToStandardError(_ message: String) {
    var stream = StandardErrorStream()
    print(message, to: &stream)
}

// MARK: - Verbosity

/// Diagnostic verbosity, resolved from `--quiet` / `--verbose`.
enum Verbosity: Int {
    /// Only errors are shown.
    case quiet = 0
    /// A concise result summary is shown (default).
    case normal = 1
    /// Per-phase progress and settings detail are shown.
    case verbose = 2
}

// MARK: - Output options (shared OptionGroup)

/// Output-mode flags shared by `generate` and `extract`. Controls whether the
/// result is human text or JSON, and how chatty the stderr diagnostics are.
struct OutputOptions: ParsableArguments {
    @Flag(name: .long, help: "Emit a single JSON object describing the result to stdout")
    var json: Bool = false

    @Flag(name: [.customShort("q"), .customLong("quiet")], help: "Suppress diagnostics; show only errors")
    var quiet: Bool = false

    @Flag(name: [.customShort("v"), .customLong("verbose")], help: "Show per-phase progress and detail on stderr")
    var verbose: Bool = false

    /// Resolved verbosity. `--quiet` wins over the normal default; `--verbose`
    /// raises it. `--quiet` and `--verbose` together are rejected in `validate()`.
    var verbosity: Verbosity {
        if quiet { return .quiet }
        if verbose { return .verbose }
        return .normal
    }

    func validate() throws {
        if quiet && verbose {
            throw ValidationError("--quiet and --verbose cannot be used together.")
        }
    }

    /// A reporter configured from these options.
    var reporter: OutputReporter {
        OutputReporter(verbosity: verbosity, json: json)
    }
}

// MARK: - Reporter

/// Routes output to the right stream: machine results (paths) to stdout, human
/// diagnostics to stderr. In `--json` mode the caller emits the JSON payload to
/// stdout instead, so the path/status/detail channels stay silent.
struct OutputReporter {
    let verbosity: Verbosity
    let json: Bool

    /// A machine-readable result line (an output file path) → stdout.
    /// Suppressed in JSON mode (the path is carried in the JSON payload instead).
    func path(_ path: String) {
        guard !json else { return }
        print(path)
    }

    /// A concise human status line → stderr. Shown at normal verbosity and above.
    func status(_ message: String) {
        guard !json, verbosity.rawValue >= Verbosity.normal.rawValue else { return }
        printToStandardError(message)
    }

    /// Verbose per-phase detail → stderr. Shown only with `--verbose`.
    func detail(_ message: String) {
        guard !json, verbosity == .verbose else { return }
        printToStandardError(message)
    }

    /// A human error line → stderr. Always shown in human mode (even `--quiet`);
    /// suppressed in JSON mode, where the caller emits a JSON error payload.
    func failure(_ message: String) {
        guard !json else { return }
        printToStandardError(message)
    }
}

// MARK: - JSON result models (stable schema)

/// One produced output file in the JSON result.
struct OutputFileJSON: Codable, Equatable {
    let path: String
    let width: Int
    let height: Int
    let bytes: Int
    /// Origin of the icon: the SF Symbol / image basename (generate) or the
    /// source bundle path (extract).
    let source: String?
}

/// A successful command result.
struct CommandResultJSON: Codable, Equatable {
    let command: String
    let status: String
    let count: Int
    let outputs: [OutputFileJSON]

    init(command: String, outputs: [OutputFileJSON]) {
        self.command = command
        self.status = "success"
        self.count = outputs.count
        self.outputs = outputs
    }
}

/// A failed command result.
struct CommandErrorJSON: Codable, Equatable {
    struct Body: Codable, Equatable {
        let kind: String
        let message: String
    }
    let command: String
    let status: String
    let error: Body

    init(command: String, kind: String, message: String) {
        self.command = command
        self.status = "error"
        self.error = Body(kind: kind, message: message)
    }
}

/// Format a byte count for humans (e.g. `84.6 KB`).
func humanByteCount(_ bytes: Int) -> String {
    if bytes < 1024 {
        return "\(bytes) bytes"
    } else if bytes < 1024 * 1024 {
        return String(format: "%.1f KB", Double(bytes) / 1024.0)
    } else {
        return String(format: "%.1f MB", Double(bytes) / (1024.0 * 1024.0))
    }
}

/// Encode a value to a stable, pretty JSON string (sorted keys, unescaped slashes).
func encodeJSON<T: Encodable>(_ value: T) -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    guard let data = try? encoder.encode(value), let string = String(data: data, encoding: .utf8) else {
        return "{\"status\":\"error\",\"error\":{\"kind\":\"encoding\",\"message\":\"Failed to encode result\"}}"
    }
    return string
}
