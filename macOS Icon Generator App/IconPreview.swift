// IconPreview.swift - Displays a preview of our icon
import SwiftUI

struct IconPreview: View {
    let settings: IconSettings
    
    var body: some View {
        ZStack {
            // Background with rounded corners
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: settings.gradientColors),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
            
            // SF Symbol icon
            Image(systemName: settings.symbolName)
                .font(.system(size: 100, weight: .light))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 2)
        }
    }
}
