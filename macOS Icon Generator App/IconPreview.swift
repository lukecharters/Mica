// IconPreview.swift - Displays a preview of our icon
import SwiftUI

struct IconPreview: View {
    let settings: IconSettings
    
    var body: some View {
        ZStack {
            // Background with rounded corners - using the squircle shape similar to macOS icons
            if settings.useCustomColors {
                RoundedRectangle(cornerRadius: 70, style: .continuous)
                    .inset(by: 25)  // Add inset to match the export (256 size uses 25 inset)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: settings.gradientColors),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(radius: 2, y: 2.5)
                    .frame(width: 256, height: 256, alignment: .center)
            } else {
                    RoundedRectangle(cornerRadius: 70, style: .continuous)
                        .inset(by: 25)  // Add inset to match the export (256 size uses 25 inset)
                        .fill(settings.baseColor.gradient)
                        .shadow(radius: 2, x: 0, y: 2.5)
                        .frame(width: 256, height: 256, alignment: .center)
                    //.shadow(radius: 2, y: 3)
            }
            
            // SF Symbol icon with appropriate rendering mode and colors
            Group {
                if settings.symbolRenderingMode == .monochrome {
                    Image(systemName: settings.symbolName)
                        .alignmentGuide(VerticalAlignment.center) { context in context[VerticalAlignment.center] + 6
                        }
                        .font(.system(size: 120, weight: .regular))
                        .foregroundColor(settings.symbolColor)
                        .symbolRenderingMode(.monochrome)
                        .shadow(radius: 2, x: 0, y: 2.5)
                        .frame(width: 178, height: 178, alignment: .center)
                        //.shadow(radius: 2, y: 2)
                } else if settings.symbolRenderingMode == .hierarchical {
                    Image(systemName: settings.symbolName)
                        .alignmentGuide(VerticalAlignment.center) { context in context[VerticalAlignment.center] + 6
                        }
                        .font(.system(size: 120, weight: .regular))
                        .foregroundStyle(settings.hierarchicalSymbolColor)
                        .symbolRenderingMode(.hierarchical)
                        .shadow(radius: 2, x: 0, y: 2.5)
                } else if settings.symbolRenderingMode == .multicolor {
                    Image(systemName: settings.symbolName)
                        .alignmentGuide(VerticalAlignment.center) { context in context[VerticalAlignment.center] + 6
                        }
                        .frame(width: 178, height: 178, alignment: .center)
                        .font(.system(size: 120, weight: .regular))
                        .symbolRenderingMode(.multicolor)
                        .shadow(radius: 2, x: 0, y: 2.5)
                } else if settings.symbolRenderingMode == .palette {
                    Image(systemName: settings.symbolName)
                        .alignmentGuide(VerticalAlignment.center) { context in context[VerticalAlignment.center] + 6
                        }
                        .frame(width: 178, height: 178, alignment: .center)
                        .font(.system(size: 120, weight: .regular))
                        .foregroundStyle(
                            settings.paletteSymbolPrimaryColor,
                            settings.paletteSymbolSecondaryColor,
                            settings.paletteSymbolTertiaryColor
                        )
                        .symbolRenderingMode(.palette)
                        .shadow(radius: 2, x: 0, y: 2.5)
                }
            }
        }
    }
}
