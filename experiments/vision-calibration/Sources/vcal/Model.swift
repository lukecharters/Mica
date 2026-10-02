import CoreGraphics
import Foundation
import FoundationModels

// MARK: - Answers

@Generable(description: "How the candidate glyph's size compares with the reference glyph's")
enum SizeComparison: String, Codable, CaseIterable {
    case muchSmaller, smaller, slightlySmaller, same, slightlyLarger, larger, muchLarger
}

@Generable(description: "Where the candidate glyph sits horizontally compared with the reference glyph")
enum HorizontalComparison: String, Codable, CaseIterable {
    case farLeft, left, slightlyLeft, aligned, slightlyRight, right, farRight
}

@Generable(description: "Where the candidate glyph sits vertically compared with the reference glyph")
enum VerticalComparison: String, Codable, CaseIterable {
    case farHigher, higher, slightlyHigher, aligned, slightlyLower, lower, farLower
}

@Generable(description: "How the candidate glyph's stroke thickness compares with the reference glyph's")
enum WeightComparison: String, Codable, CaseIterable {
    case muchThinner, thinner, same, thicker, muchThicker
}

@Generable(description: "A comparison of a candidate glyph against a reference glyph")
struct Comparison: Codable {
    @Guide(description: "Compared with the reference, is the candidate glyph smaller, the same size, or larger?")
    var size: SizeComparison
    @Guide(description: "Compared with the reference, is the candidate glyph further left, aligned, or further right?")
    var horizontal: HorizontalComparison
    @Guide(description: "Compared with the reference, is the candidate glyph higher, aligned, or lower?")
    var vertical: VerticalComparison
    @Guide(description: "Compared with the reference, are the candidate glyph's strokes thinner, the same, or thicker?")
    var weight: WeightComparison
}

@Generable(description: "A comparison of a candidate glyph against a reference glyph, with a note on what was seen first")
struct ComparisonWithNote: Codable {
    @Guide(description: "One sentence on where the edges of the two glyphs disagree")
    var observation: String
    var size: SizeComparison
    var horizontal: HorizontalComparison
    var vertical: VerticalComparison
    var weight: WeightComparison

    var comparison: Comparison { Comparison(size: size, horizontal: horizontal, vertical: vertical, weight: weight) }
}

@Generable(description: "Numeric corrections that would make the candidate glyph match the reference glyph")
struct Estimate: Codable {
    @Guide(description: "The reference glyph's size as a percentage of the candidate glyph's size. 100 means equal; 110 means the reference is 10% larger.", .range(50.0...200.0))
    var referenceSizePercent: Double
    @Guide(description: "How far the candidate glyph must move right to line up with the reference, as a percentage of the image width. Negative moves it left.", .range(-30.0...30.0))
    var moveRightPercent: Double
    @Guide(description: "How far the candidate glyph must move down to line up with the reference, as a percentage of the image height. Negative moves it up.", .range(-30.0...30.0))
    var moveDownPercent: Double
    @Guide(description: "Compared with the reference, are the candidate glyph's strokes thinner, the same, or thicker?")
    var weight: WeightComparison
}

// MARK: - Model

enum ModelChoice: String, CaseIterable {
    case ondevice, pcc
}

struct ModelCall<T> {
    var value: T?
    var error: String?
    var seconds: Double
}

struct ModelRunner {
    let choice: ModelChoice
    let reasoning: ContextOptions.ReasoningLevel?
    let maximumResponseTokens: Int

    static func reasoningLevel(named name: String) -> ContextOptions.ReasoningLevel? {
        switch name {
        case "light": .light
        case "moderate": .moderate
        case "deep": .deep
        default: nil
        }
    }

    static func availabilityReport() async -> String {
        var lines: [String] = []
        let system = SystemLanguageModel.default
        lines.append("on-device: \(system.availability)")
        lines.append("  vision=\(system.capabilities.contains(.vision)) reasoning=\(system.capabilities.contains(.reasoning)) guided=\(system.capabilities.contains(.guidedGeneration))")
        lines.append("  contextSize=\(system.contextSize)")
        let pcc = PrivateCloudComputeLanguageModel()
        lines.append("pcc: \(pcc.availability)")
        lines.append("  vision=\(pcc.capabilities.contains(.vision)) reasoning=\(pcc.capabilities.contains(.reasoning)) guided=\(pcc.capabilities.contains(.guidedGeneration))")
        if let size = try? await pcc.contextSize { lines.append("  contextSize=\(size)") }
        lines.append("  quota=\(pcc.quotaUsage)")
        return lines.joined(separator: "\n")
    }

    static func textCheck() async -> String {
        var lines: [String] = []
        for choice in ModelChoice.allCases {
            let session: LanguageModelSession = switch choice {
            case .ondevice: LanguageModelSession(model: SystemLanguageModel.default)
            case .pcc: LanguageModelSession(model: PrivateCloudComputeLanguageModel())
            }
            do {
                let r = try await session.respond(to: "Reply with the single word: ready")
                lines.append("\(choice.rawValue) text-only: \(r.content)")
            } catch {
                lines.append("\(choice.rawValue) text-only failed: \(error)")
            }
        }
        return lines.joined(separator: "\n")
    }

    func ask<T: Generable>(_ type: T.Type, instructions: String, prompt: String, images: [CGImage]) async -> ModelCall<T> {
        let started = Date()
        let session: LanguageModelSession = switch choice {
        case .ondevice: LanguageModelSession(model: SystemLanguageModel.default, instructions: instructions)
        case .pcc: LanguageModelSession(model: PrivateCloudComputeLanguageModel(), instructions: instructions)
        }
        let options = GenerationOptions(samplingMode: .greedy, maximumResponseTokens: maximumResponseTokens)
        let context = ContextOptions(includeSchemaInPrompt: true, reasoningLevel: reasoning)
        do {
            let response = try await session.respond(generating: T.self, options: options, contextOptions: context) {
                prompt
                for image in images {
                    Attachment(image)
                }
            }
            return ModelCall(value: response.content, seconds: Date().timeIntervalSince(started))
        } catch {
            return ModelCall(error: String(describing: error), seconds: Date().timeIntervalSince(started))
        }
    }
}

// MARK: - Prompts

enum Prompts {
    static let instructions = """
        You compare two renderings of the same app-icon glyph and report how the second one \
        (the candidate) differs from the first (the reference). Judge only geometry: size, \
        position and stroke thickness. Colour and shading differences do not matter. Answer \
        "same" or "aligned" only when you see no difference.
        """

    static func describe(_ view: Composite.View) -> String {
        switch view {
        case .overlay:
            "The image overlays the two glyphs: pixels only in the reference are red, pixels only in the candidate are cyan, and pixels in both are white. Grey lines mark the centre and the icon's background square. Red fringes show where the reference extends past the candidate; cyan fringes show the opposite."
        case .pair:
            "The image shows two icons side by side: the reference on the left and the candidate on the right. Faint lines mark each icon's centre."
        case .both:
            "The first image overlays the two glyphs: pixels only in the reference are red, pixels only in the candidate are cyan, and pixels in both are white. The second image shows the two icons side by side, reference left and candidate right."
        }
    }

    static func images(_ view: Composite.View, reference: CGImage, candidate: CGImage,
                       referenceMask: GlyphMask, candidateMask: GlyphMask) -> [CGImage] {
        switch view {
        case .overlay: [Composite.overlay(reference: referenceMask, candidate: candidateMask)]
        case .pair: [Composite.pair(reference: reference, candidate: candidate)]
        case .both: [Composite.overlay(reference: referenceMask, candidate: candidateMask),
                     Composite.pair(reference: reference, candidate: candidate)]
        }
    }
}
