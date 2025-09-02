//
//  SymbolGalleryView.swift
//  macOS Icon Generator App
//
//  Created by Luke Charters on 31/8/2025.
//


import SwiftUI

struct SymbolGalleryView: View {
    let fontWeights: [Font.Weight] = [
        .ultraLight, .thin, .light, .regular,
        .medium, .semibold, .bold, .heavy, .black
    ]
    
    let variableValues: [Double] = [0.0, 0.25, 0.5, 0.75, 1.0]
    let speakerValues: [Double] = [0.0, 0.3, 0.6, 0.9]
    let batteryValues: [Int] = [0, 25, 50, 75, 100]
    let symbolVariants: [SymbolVariants] = [
        .none, .slash, .fill, .circle, .square, .rectangle
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                
                //row 1: rendering modes + .palette examples
                HStack(spacing: 16) {
                    Image(systemName: "person.crop.circle.badge.plus")
                        .symbolRenderingMode(.monochrome)

                    Image(systemName: "person.crop.circle.badge.plus")
                        .symbolRenderingMode(.hierarchical)

                    Image(systemName: "person.crop.circle.badge.plus")
                        .symbolRenderingMode(.multicolor)

                    Image(systemName: "cloud.sun.fill")
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.blue, .yellow)

                    Image(systemName: "person.3.sequence.fill")
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(
                            .linearGradient(colors: [.cyan, .black], startPoint: .top, endPoint: .bottomTrailing),
                            .linearGradient(colors: [.yellow, .black], startPoint: .top, endPoint: .bottomTrailing),
                            .linearGradient(colors: [.blue, .black], startPoint: .top, endPoint: .bottomTrailing)
                        )

                    Image(systemName: "person.3.sequence.fill")
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.ultraThickMaterial, .regularMaterial, .ultraThinMaterial)
                }
                .font(.system(size: 24))

                //row 2: resizing, font weights, symbol variants
                HStack(spacing: 16) {
                    Image(systemName: "plus")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)

                    Image(systemName: "plus")
                        .font(.system(size: 24))

                    ForEach(fontWeights, id: \.self) { weight in
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 24, weight: weight))
                            .foregroundStyle(.brown)
                    }

                    ForEach(symbolVariants, id: \.self) { variant in
                        Image(systemName: "heart")
                            .symbolVariant(variant)
                            .font(.system(size: 32))
                            .foregroundStyle(.pink)
                    }
                }

                //row 3: variable values (wifi, speaker, battery)
                HStack(spacing: 16) {
                    ForEach(variableValues, id: \.self) { value in
                        Image(systemName: "wifi", variableValue: value)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.indigo)
                            .font(.system(size: 32))
                    }

                    ForEach(speakerValues, id: \.self) { value in
                        Image(systemName: "speaker.wave.3", variableValue: value)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.cyan)
                            .font(.system(size: 32))
                    }

                    ForEach(batteryValues, id: \.self) { value in
                        Image(systemName: "battery.\(value)")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.indigo)
                            .font(.system(size: 32))
                    }
                }
            }
            .padding()
        }
    }
}

#Preview {
    SymbolGalleryView()
}
