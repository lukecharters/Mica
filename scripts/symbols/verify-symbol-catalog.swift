// Checks Mica/Resources/symbol-catalog.json against the running macOS.
//
//   swift scripts/symbols/verify-symbol-catalog.swift [path/to/symbol-catalog.json]
//
// Every symbol, retired symbol and alias whose macOS version is at or below this Mac's
// must resolve through NSImage(systemSymbolName:), and every alias must draw the same
// pixels as its current name. Exits non-zero, listing the failures, if any do not.

import AppKit

struct Alias: Decodable {
    let name: String
    let macOS: String?
}

struct Entry: Decodable {
    let name: String
    let macOS: String
    let aliases: [Alias]?
}

struct Catalog: Decodable {
    let formatVersion: Int
    let symbols: [Entry]
    let retired: [Entry]
}

func parse(_ text: String) -> OperatingSystemVersion {
    let parts = text.split(separator: ".").compactMap { Int($0) }
    return OperatingSystemVersion(
        majorVersion: parts.first ?? 0,
        minorVersion: parts.count > 1 ? parts[1] : 0,
        patchVersion: parts.count > 2 ? parts[2] : 0
    )
}

func available(_ text: String?) -> Bool {
    guard let text else { return true }
    return ProcessInfo.processInfo.isOperatingSystemAtLeast(parse(text))
}

func pixels(_ name: String) -> Data? {
    let configuration = NSImage.SymbolConfiguration(pointSize: 64, weight: .regular)
    guard let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
        .withSymbolConfiguration(configuration) else { return nil }
    var rect = NSRect(origin: .zero, size: image.size)
    guard let cgImage = image.cgImage(forProposedRect: &rect, context: nil, hints: nil) else { return nil }
    return NSBitmapImageRep(cgImage: cgImage).representation(using: .png, properties: [:])
}

let scriptURL = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL
let defaultPath = scriptURL.deletingLastPathComponent()
    .appendingPathComponent("../../Mica/Resources/symbol-catalog.json").standardizedFileURL.path
let path = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : defaultPath

let catalog: Catalog
do {
    catalog = try JSONDecoder().decode(Catalog.self, from: Data(contentsOf: URL(fileURLWithPath: path)))
} catch {
    FileHandle.standardError.write("verify-symbol-catalog: cannot read \(path): \(error)\n".data(using: .utf8)!)
    exit(1)
}

var failures: [String] = []
var checked = 0
var skipped = 0

for entry in catalog.symbols + catalog.retired {
    guard available(entry.macOS) else { skipped += 1; continue }
    checked += 1
    guard let reference = pixels(entry.name) else {
        failures.append("\(entry.name): does not resolve")
        continue
    }
    for alias in entry.aliases ?? [] where available(alias.macOS) {
        checked += 1
        guard let aliasPixels = pixels(alias.name) else {
            failures.append("\(alias.name) (alias of \(entry.name)): does not resolve")
            continue
        }
        if aliasPixels != reference {
            failures.append("\(alias.name) (alias of \(entry.name)): draws different pixels")
        }
    }
}

let os = ProcessInfo.processInfo.operatingSystemVersionString
print("verify-symbol-catalog: \(checked) names checked on \(os), \(skipped) symbols newer than this macOS skipped")
if !failures.isEmpty {
    print("\(failures.count) failures:")
    failures.forEach { print("  \($0)") }
    exit(1)
}
