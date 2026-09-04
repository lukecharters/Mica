// Views/Controls/WrappingHStack.swift
import SwiftUI

/// An `HStack` that starts a new row when the next subview will not fit the
/// width it is given, instead of growing past it.
struct WrappingHStack: Layout {
    var horizontalSpacing: CGFloat = 4
    var verticalSpacing: CGFloat = 4

    /// Where each subview goes, in the layout's own coordinate space, and the
    /// size the rows add up to.
    struct Arrangement: Equatable {
        var frames: [CGRect]
        var size: CGSize
    }

    /// Rows are filled left to right. A subview wider than `maxWidth` takes a row
    /// of its own and the reported width grows to hold it, so it overflows to the
    /// trailing edge rather than being clipped or drawn over a neighbour.
    static func arrange(
        sizes: [CGSize],
        in maxWidth: CGFloat,
        horizontalSpacing: CGFloat,
        verticalSpacing: CGFloat
    ) -> Arrangement {
        var frames: [CGRect] = []
        frames.reserveCapacity(sizes.count)
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var widest: CGFloat = 0

        for size in sizes {
            let startsNewRow = x > 0 && x + size.width > maxWidth
            if startsNewRow {
                y += rowHeight + verticalSpacing
                x = 0
                rowHeight = 0
            }
            frames.append(CGRect(origin: CGPoint(x: x, y: y), size: size))
            x += size.width
            widest = max(widest, x)
            x += horizontalSpacing
            rowHeight = max(rowHeight, size.height)
        }

        let height = frames.isEmpty ? 0 : y + rowHeight
        return Arrangement(frames: frames, size: CGSize(width: widest, height: height))
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrangement(for: subviews, width: proposal.width ?? .infinity).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let arrangement = arrangement(for: subviews, width: bounds.width)
        for (subview, frame) in zip(subviews, arrangement.frames) {
            subview.place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                anchor: .topLeading,
                proposal: ProposedViewSize(frame.size)
            )
        }
    }

    private func arrangement(for subviews: Subviews, width: CGFloat) -> Arrangement {
        Self.arrange(
            sizes: subviews.map { $0.sizeThatFits(.unspecified) },
            in: width,
            horizontalSpacing: horizontalSpacing,
            verticalSpacing: verticalSpacing
        )
    }
}

#Preview {
    WrappingHStack {
        ForEach(43...66, id: \.self) { value in
            Button(String(format: "%.2f", Double(value) / 100)) {}
                .buttonStyle(.bordered)
                .controlSize(.mini)
        }
    }
    .frame(width: 320)
    .padding()
}
