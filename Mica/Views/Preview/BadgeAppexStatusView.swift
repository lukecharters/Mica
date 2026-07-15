// Views/Preview/BadgeAppexStatusView.swift
import SwiftUI

/// Preview-only stand-in drawn where a System-mode badge will appear while its
/// appex image is still generating, or after generation fails. Lives outside the
/// shared render path (`BadgeView`) so it can never leak into an exported PNG.
struct BadgeAppexStatusView: View {
    let badgeSize: CGFloat
    var error: String? = nil

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.secondary.opacity(0.2))
            if let error {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: badgeSize * 0.4))
                    .foregroundStyle(.yellow)
                    .help(error)
                    .accessibilityLabel("Badge generation failed: \(error)")
            } else {
                ProgressView()
                    .scaleEffect(0.5)
            }
        }
        .frame(width: badgeSize, height: badgeSize)
    }
}

#Preview("Generating") {
    BadgeAppexStatusView(badgeSize: 80)
        .padding()
}

#Preview("Failed") {
    BadgeAppexStatusView(badgeSize: 80, error: "Symbol not found")
        .padding()
}
