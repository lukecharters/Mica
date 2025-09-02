//
//  SymbolCheatsheetView.swift
//  macOS Icon Generator App
//
//  Created by Luke Charters on 31/8/2025.
//


import SwiftUI

struct SymbolCheatsheetView: View {
    let fontWeights: [Font.Weight] = [
        .ultraLight, .thin, .light, .regular,
        .medium, .semibold, .bold, .heavy, .black
    ]
    
    let variableValues: [Double] = [0.0, 0.25, 0.5, 0.75, 1.0]
    
    let symbolVariants: [SymbolVariants] = [
        .none, .slash, .fill, .circle, .square, .rectangle
    ]
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                
                Group {
                    Text(".symbolRenderingMode(.xx)").font(.title.bold())
                    
                    HStack(spacing: 20) {
                        Label(".monochrome", systemImage: "person.crop.circle.badge.plus")
                            .symbolRenderingMode(.monochrome)
                        
                        Label(".hierarchical", systemImage: "person.crop.circle.badge.plus")
                            .symbolRenderingMode(.hierarchical)
                        
                        Label(".multicolor", systemImage: "person.crop.circle.badge.plus")
                            .symbolRenderingMode(.multicolor)
                    }
                    .foregroundStyle(.blue)

                    
                    VStack(alignment: .leading) {
                        Text(".palette: ")
                        
                        HStack(spacing: 20) {
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
                                .foregroundStyle(
                                    .ultraThickMaterial,
                                    .regularMaterial,
                                    .ultraThinMaterial
                                )
                                .padding()
                                .background(.indigo)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        }

                    
                    }
                }
                .font(.system(size: 24))

                
                Divider()
                Group {
                    Text(".resizable().scaledToFit().frame(width: xx, height: xx) \nvs .font(.system(size: xx))").font(.title.bold())
                    HStack {
                        Image(systemName: "plus")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)

                        Image(systemName: "plus")
                            .font(.system(size: 24))
                    }
                    .background(.blue.opacity(0.2))
                }
                
                
                Group {
                    Text(".font(.system(size: 24, weight: .xx))").font(.title.bold())
                    HStack(spacing: 6) {
                        ForEach(fontWeights, id: \.self) { weight in
                            Image(systemName: "checkmark.circle")
                                .font(.system(size: 24, weight: weight))
                        }
                    }
                    .foregroundStyle(.brown)
                }
                
                Divider()
                
                Group {
                    Text(".variableValue(.xx) - 0.2, 0.5 .. <1.0").font(.title.bold())
                    
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Wi-Fi").font(.headline)
                        HStack {
                            ForEach(variableValues, id: \.self) { value in
                                Image(systemName: "wifi", variableValue: value)
                                    .symbolRenderingMode(.hierarchical)
                                    .foregroundStyle(.indigo)
                                    .font(.system(size: 32))
                            }
                        }

                        Text("Speaker Volume").font(.headline)
                        HStack {
                            ForEach([0.0, 0.3, 0.6, 0.9], id: \.self) { value in
                                Image(systemName: "speaker.wave.3", variableValue: value)
                                    .symbolRenderingMode(.hierarchical)
                                    .foregroundStyle(.cyan)
                                    .font(.system(size: 32))
                            }
                        }

                        Text("EXCEPTION: Battery Levels\nbattery.0, battery.25...battery.100").font(.headline)
                        HStack {
                            ForEach([0, 25, 50, 75, 100], id: \.self) { value in
                                Image(systemName: "battery.\(value)")
                                    .symbolRenderingMode(.hierarchical)
                                    .foregroundStyle(.indigo)
                                    .font(.system(size: 32))
                            }
                        }
                    }
                }
                
                Divider()
                
                Group {
                    Text(".symbolVariant(.xx) - \n.none, .slash, .fill, .circle, .square, .rectangle").font(.title.bold())
                    HStack {
                        ForEach(symbolVariants, id: \.self) { variant in
                            Image(systemName: "heart")
                                .symbolVariant(variant)
                                .font(.system(size: 32))
                        }
                    }
                    .foregroundStyle(.pink)
                }
            }
            .padding()
        }
    }
}

#Preview {
    SymbolCheatsheetView()
}