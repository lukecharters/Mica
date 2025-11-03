//
//  BlurGlassTextAlternative.swift
//  macOS Icon Generator App
//
//  Created by Luke Charters on 3/11/2025.
//

import SwiftUI
import LiquidGlassText

struct BlurGlassTextAlternative: View {
    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.blue)
            
            // A dynamic background is essential to see the blur
            Image(systemName: "sun.max.fill")
                .resizable()
                .scaledToFill()
                .frame(width: 400, height: 400)
                .foregroundColor(Color.white)
                .clipped()
            
            // The "Glass" Effect Layer
            Rectangle() // Or any other view to hold the background
                .background(.ultraThinMaterial) // The blur effect
                .blendMode(.overlay) // Optional: For a brighter, more integrated look
                .mask(
                    Text("SwiftUI Glass")
                        .font(.system(size: 80, weight: .black))
                )
        }
        .frame(width: 400, height: 400)
        .cornerRadius(20) // To contain the background image
        ZStack{
            Rectangle()
                .fill(Color.blue)
            LiquidGlassText("SwiftUI Glass", size: 80)
                .font(.system(size: 80, weight: .black))
                .frame(width: 400, height: 800)
                .cornerRadius(20)
        }
        }
    }

#Preview {
    BlurGlassTextAlternative()
}
