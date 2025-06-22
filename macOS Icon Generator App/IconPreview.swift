// IconPreview.swift - Displays a preview of our icon
import SwiftUI

struct IconPreview: View {
    let settings: IconSettings
    
    // Layout constants
    private let iconSize: CGFloat = 256
    private let cornerRadius: CGFloat = 70
    private let backgroundInset: CGFloat = 25
    private let symbolSize: CGFloat = 120
    private let symbolFrameSize: CGFloat = 178
    private let shadowRadius: CGFloat = 2
    private let shadowOffset: CGFloat = 2.5
    private let verticalAlignmentOffset: CGFloat = 5.5
    private let symbolWeight: Font.Weight = .regular
    
    var body: some View {
        ZStack {
            // Background with rounded corners - using the squircle shape similar to macOS icons
            if settings.useCustomColors {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .inset(by: backgroundInset)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: settings.gradientColors),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(radius: shadowRadius, y: shadowOffset)
                    .frame(width: iconSize, height: iconSize, alignment: .center)
            } else {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .inset(by: backgroundInset)
                    .fill(settings.baseColor.gradient)
                    .shadow(radius: shadowRadius, x: 0, y: shadowOffset)
                    .frame(width: iconSize, height: iconSize, alignment: .center)
            }
            
            // SF Symbol icon with appropriate rendering mode and colors
            Group {
                if settings.symbolRenderingMode == .monochrome {
                    Image(systemName: settings.symbolName)
                        .alignmentGuide(VerticalAlignment.center) { context in 
                            context[VerticalAlignment.center] + verticalAlignmentOffset
                        }
                        .font(.system(size: symbolSize, weight: symbolWeight))
                        .foregroundColor(settings.symbolColor)
                        .symbolRenderingMode(.monochrome)
                        .shadow(radius: shadowRadius, x: 0, y: shadowOffset)
                        .frame(width: symbolFrameSize, height: symbolFrameSize, alignment: .center)
                } else if settings.symbolRenderingMode == .hierarchical {
                    Image(systemName: settings.symbolName)
                        .alignmentGuide(VerticalAlignment.center) { context in 
                            context[VerticalAlignment.center] + verticalAlignmentOffset
                        }
                        .font(.system(size: symbolSize, weight: symbolWeight))
                        .foregroundStyle(settings.hierarchicalSymbolColor)
                        .symbolRenderingMode(.hierarchical)
                        .shadow(radius: shadowRadius, x: 0, y: shadowOffset)
                } else if settings.symbolRenderingMode == .multicolor {
                    Image(systemName: settings.symbolName)
                        .alignmentGuide(VerticalAlignment.center) { context in 
                            context[VerticalAlignment.center] + verticalAlignmentOffset
                        }
                        .font(.system(size: symbolSize, weight: symbolWeight))
                        .symbolRenderingMode(.multicolor)
                        .shadow(radius: shadowRadius, x: 0, y: shadowOffset)
                } else if settings.symbolRenderingMode == .palette {
                    Image(systemName: settings.symbolName)
                        .alignmentGuide(VerticalAlignment.center) { context in 
                            context[VerticalAlignment.center] + verticalAlignmentOffset
                        }
                        .font(.system(size: symbolSize, weight: symbolWeight))
                        .foregroundStyle(
                            settings.paletteSymbolPrimaryColor,
                            settings.paletteSymbolSecondaryColor,
                            settings.paletteSymbolTertiaryColor
                        )
                        .symbolRenderingMode(.palette)
                        .shadow(radius: shadowRadius, x: 0, y: shadowOffset)
                }
            }
        }
    }
}