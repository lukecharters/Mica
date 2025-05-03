// IconPreview.swift - Displays a preview of our icon
import SwiftUI

struct IconPreview: View {
    let settings: IconSettings
    
    var body: some View {
        ZStack {
            // Background with rounded corners - using the squircle shape similar to macOS icons
            if settings.useCustomColors {
                RoundedRectangle(cornerRadius: 42, style: .continuous)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: settings.gradientColors),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 2)
            } else {
                RoundedRectangle(cornerRadius: 42, style: .continuous)
                    .fill(settings.baseColor.gradient)
                    .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 2)
            }
            
            // SF Symbol icon with appropriate rendering mode and colors
            Group {
                if settings.symbolRenderingMode == .monochrome {
                    Image(systemName: settings.symbolName)
                        .font(.system(size: 110, weight: .light))
                        .foregroundColor(settings.symbolColor)
                        .symbolRenderingMode(.monochrome)
                        .shadow(color: .black.opacity(0.25), radius: 1, x: 0, y: 1)
                } else if settings.symbolRenderingMode == .hierarchical {
                    Image(systemName: settings.symbolName)
                        .font(.system(size: 110, weight: .light))
                        .foregroundStyle(settings.hierarchicalSymbolColor)
                        .symbolRenderingMode(.hierarchical)
                        .shadow(color: .black.opacity(0.25), radius: 1, x: 0, y: 1)
                } else if settings.symbolRenderingMode == .multicolor {
                    Image(systemName: settings.symbolName)
                        .font(.system(size: 110, weight: .light))
                        .symbolRenderingMode(.multicolor)
                        .shadow(color: .black.opacity(0.25), radius: 1, x: 0, y: 1)
                } else if settings.symbolRenderingMode == .palette {
                    Image(systemName: settings.symbolName)
                        .font(.system(size: 110, weight: .light))
                        .foregroundStyle(
                            settings.paletteSymbolPrimaryColor,
                            settings.paletteSymbolSecondaryColor,
                            settings.paletteSymbolTertiaryColor
                        )
                        .symbolRenderingMode(.palette)
                        .shadow(color: .black.opacity(0.25), radius: 1, x: 0, y: 1)
                }
            }
        }
    }
}
