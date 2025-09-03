//
//  LiquidGlassTestGrid.swift
//  macOS Icon Generator App
//
//  Created by Luke Charters on 2/9/2025.
//

import SwiftUI

// Individual icon views - each can be separately customized
struct Icon1View: View {
    var displaySize: CGFloat { 256 }
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 46, style: .continuous)
                .fill(.blue.gradient)
                .shadow(radius: 2, x: 0, y: 2.5)
                .frame(width: 206, height: 206)
            
            Image(systemName: "folder.fill.badge.plus")
                .font(.system(size: 120, weight: .regular))
                .offset(x: 0, y: -2)
                .frame(width: 165, height: 165, alignment: .center)
                .foregroundColor(.white)
                .shadow(radius: 2, x: 0, y: 2.5)
            
            Circle()
                //.fill(.clear)
                .fill(Color.gray.gradient)
                .frame(width: displaySize * 0.31, height: displaySize * 0.31)
                .shadow(color: .black.opacity(0.31), radius: 2, x: 0, y: 1)
                .overlay(
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: displaySize * 0.18, weight: .regular))
                        .foregroundColor(.white)
                )
                //.glassEffect(.clear, in: Circle())
                .offset(x: displaySize * 0.3, y: displaySize * 0.3)
        }
        .frame(width: displaySize, height: displaySize)
    }
}

struct Icon2View: View {
    var displaySize: CGFloat { 256 }
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 46, style: .continuous)
                .fill(.blue.gradient)
                .fill(.clear)
                .shadow(radius: 2, x: 0, y: 2.5)
                //.glassEffect(.regular, in: RoundedRectangle(cornerRadius: 46))
                .frame(width: 206, height: 206)
            //.fill(.clear)
        //.glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius))
            //.glassEffect(.regular.tint(.blue), in: RoundedRectangle(cornerRadius: cornerRadius))
            //.glassEffect(.identity, in: RoundedRectangle(cornerRadius: cornerRadius))

            
            Image(systemName: "folder.fill.badge.plus")
                .font(.system(size: 120, weight: .regular))
                .offset(x: 0, y: -2)
                .frame(width: 206, height: 206, alignment: .center)
                .foregroundColor(.white)
                .shadow(radius: 2, x: 0, y: 2.5)
                .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 46))
            
            Circle()
                .fill(.clear)
//                .fill(Color.gray.gradient)
                .frame(width: displaySize * 0.31, height: displaySize * 0.31)
                .shadow(color: .black.opacity(0.31), radius: 2, x: 0, y: 1)
                .overlay(
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: displaySize * 0.18, weight: .regular))
                        .foregroundColor(.white)
                )
                .glassEffect(.clear, in: Circle())
                .offset(x: displaySize * 0.3, y: displaySize * 0.3)
        }
        .frame(width: displaySize, height: displaySize)
    }
}

struct Icon3View: View {
    var displaySize: CGFloat { 256 }
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 46, style: .continuous)
                .fill(.blue.gradient)
                .shadow(radius: 2, x: 0, y: 2.5)
                .frame(width: 206, height: 206)
                .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 46))
            
            Image(systemName: "folder.fill.badge.plus")
                .font(.system(size: 120, weight: .regular))
                .offset(x: 0, y: -2)
                .frame(width: 165, height: 165, alignment: .center)
                .foregroundColor(.white)
                .shadow(radius: 2, x: 0, y: 2.5)
            
            Circle()
            .fill(.clear)
                //.fill(Color.gray.gradient)
                .frame(width: displaySize * 0.31, height: displaySize * 0.31)
                .shadow(color: .black.opacity(0.31), radius: 2, x: 0, y: 1)
                .overlay(
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: displaySize * 0.18, weight: .regular))
                        .foregroundColor(.white)
                )
                .glassEffect(.clear.tint(.black.opacity(0.30)), in: Circle())
                .offset(x: displaySize * 0.3, y: displaySize * 0.3)
        }
        .frame(width: displaySize, height: displaySize)
    }
}

struct Icon4View: View {
    var displaySize: CGFloat { 256 }
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 46, style: .continuous)
                //.fill(.blue.gradient)
                //.glassEffect(.regular.tint(.blue), in: RoundedRectangle(cornerRadius: 46))
                .shadow(radius: 2, x: 0, y: 2.5)
                .frame(width: 206, height: 206)

            Image(systemName: "folder.fill.badge.plus")
                .font(.system(size: 120, weight: .regular))
                .offset(x: 0, y: -2)
                .frame(width: 206, height: 206, alignment: .center)
                .foregroundColor(.white)
                .shadow(radius: 2, x: 0, y: 2.5)
                .glassEffect(.regular.tint(.blue), in: RoundedRectangle(cornerRadius: 46))
            
            Circle()
                //.fill(Color.gray.gradient)
                .fill(.clear)
                .frame(width: displaySize * 0.31, height: displaySize * 0.31)
                .shadow(color: .black.opacity(0.31), radius: 2, x: 0, y: 1)
                .overlay(
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: displaySize * 0.18, weight: .regular))
                        .foregroundColor(.white)
                )
                .glassEffect(.regular, in: Circle())
                .offset(x: displaySize * 0.3, y: displaySize * 0.3)
        }
        .frame(width: displaySize, height: displaySize)
    }
}

struct Icon5View: View {
    var displaySize: CGFloat { 256 }
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 46, style: .continuous)
            .fill(.blue.gradient)
            //.fill(.clear)
            .strokeBorder(Color.white.opacity(0.90), lineWidth: 10)
            .frame(width: 206, height: 206)
            //.fill(.blue.gradient)
            RoundedRectangle(cornerRadius: 46, style: .continuous)
                .fill(.clear)
                //.fill(.blue.gradient)
                .shadow(radius: 2, x: 0, y: 2.5)
                .frame(width: 206, height: 206)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 46))
            
            Image(systemName: "folder.fill.badge.plus")
                .font(.system(size: 120, weight: .regular))
                .offset(x: 0, y: -2)
                .frame(width: 165, height: 165, alignment: .center)
                .foregroundColor(.white)
                .shadow(radius: 2, x: 0, y: 2.5)
            
            
            Circle()
                //.fill(Color.gray.gradient)
                .fill(.clear)
                .frame(width: displaySize * 0.31, height: displaySize * 0.31)
                .shadow(color: .black.opacity(0.31), radius: 2, x: 0, y: 1)
                .overlay(
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: displaySize * 0.18, weight: .regular))
                        .foregroundColor(.white)
                )
                .glassEffect(.regular.tint(.black.opacity(0.30)), in: Circle())
                .offset(x: displaySize * 0.3, y: displaySize * 0.3)
        }
        .frame(width: displaySize, height: displaySize)
    }
}

struct Icon6View: View {
    var displaySize: CGFloat { 256 }
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 46, style: .continuous)
            .fill(.blue.gradient)
            //.fill(.clear)
            .strokeBorder(Color.white.opacity(0.99), lineWidth: 13)
            .frame(width: 206, height: 206)
            //.fill(.blue.gradient)
            RoundedRectangle(cornerRadius: 46, style: .continuous)
                .fill(.clear)
                //.fill(.blue.gradient)
                .shadow(radius: 2, x: 0, y: 2.5)
                .frame(width: 206, height: 206)
                .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 46))
            
            Image(systemName: "folder.fill.badge.plus")
                .font(.system(size: 120, weight: .regular))
                .offset(x: 0, y: -2)
                .frame(width: 165, height: 165, alignment: .center)
                .foregroundColor(.white)
                .shadow(radius: 2, x: 0, y: 2.5)
            
            Circle()
                //.fill(Color.gray.gradient)
                .fill(.clear)
                .frame(width: displaySize * 0.31, height: displaySize * 0.31)
                .shadow(color: .black.opacity(0.31), radius: 2, x: 0, y: 1)
                .overlay(
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: displaySize * 0.18, weight: .regular))
                        .foregroundColor(.white)
                )
                .glassEffect(.regular.tint(.black.opacity(0.30)), in: Circle())
                .offset(x: displaySize * 0.3, y: displaySize * 0.3)
        }
        .frame(width: displaySize, height: displaySize)
    }
}

struct Icon7View: View {
    var displaySize: CGFloat { 256 }
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 46, style: .continuous)
                .fill(.blue.gradient)
                .shadow(radius: 2, x: 0, y: 2.5)
                .frame(width: 206, height: 206)
            
            Image(systemName: "folder.fill.badge.plus")
                .font(.system(size: 120, weight: .regular))
                .offset(x: 0, y: -2)
                .frame(width: 195, height: 195, alignment: .center)
                .foregroundColor(.white)
                .shadow(radius: 2, x: 0, y: 2.5)
                .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 44))
            
            Circle()
                .fill(Color.gray.gradient)
                .frame(width: displaySize * 0.31, height: displaySize * 0.31)
                .shadow(color: .black.opacity(0.31), radius: 2, x: 0, y: 1)
                .overlay(
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: displaySize * 0.18, weight: .regular))
                        .foregroundColor(.white)
                )
                .offset(x: displaySize * 0.3, y: displaySize * 0.3)
        }
        .frame(width: displaySize, height: displaySize)
    }
}

struct Icon8View: View {
    var displaySize: CGFloat { 256 }
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 46, style: .continuous)
                .fill(.blue.gradient)
                .shadow(radius: 2, x: 0, y: 2.5)
                .frame(width: 206, height: 206)
            
            Image(systemName: "folder.fill.badge.plus")
                .font(.system(size: 120, weight: .regular))
                .offset(x: 0, y: -2)
                .frame(width: 165, height: 165, alignment: .center)
                .foregroundColor(.white)
                .shadow(radius: 2, x: 0, y: 2.5)
            RoundedRectangle(cornerRadius: 46, style: .continuous)
                .frame(width: 206, height: 206)
                .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 46))
            
            Circle()
                .fill(Color.gray.gradient)
                .frame(width: displaySize * 0.31, height: displaySize * 0.31)
                .shadow(color: .black.opacity(0.31), radius: 2, x: 0, y: 1)
                .overlay(
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: displaySize * 0.18, weight: .regular))
                        .foregroundColor(.white)
                )
                .offset(x: displaySize * 0.3, y: displaySize * 0.3)
        }
        .frame(width: displaySize, height: displaySize)
    }
}

struct Icon9View: View {
    var displaySize: CGFloat { 256 }
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 46, style: .continuous)
                .fill(.blue.gradient)
                .shadow(radius: 2, x: 0, y: 2.5)
                .frame(width: 206, height: 206)
            
            Image(systemName: "folder.fill.badge.plus")
                .font(.system(size: 120, weight: .regular))
                .offset(x: 0, y: -2)
                .frame(width: 165, height: 165, alignment: .center)
                .foregroundColor(.white)
                .shadow(radius: 2, x: 0, y: 2.5)
            RoundedRectangle(cornerRadius: 46, style: .continuous)
                .frame(width: 206, height: 206)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 46))
            
            Circle()
                .fill(Color.gray.gradient)
                .frame(width: displaySize * 0.31, height: displaySize * 0.31)
                .shadow(color: .black.opacity(0.31), radius: 2, x: 0, y: 1)
                .overlay(
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: displaySize * 0.18, weight: .regular))
                        .foregroundColor(.white)
                )
                .offset(x: displaySize * 0.3, y: displaySize * 0.3)
        }
        .frame(width: displaySize, height: displaySize)
    }
}

struct LiquidGlassTestGrid: View {
    
    // List of icon titles for grid iteration
    let iconTitles = ["Icon 1", "Icon 2", "Icon 3", "Icon 4", "Icon 5", "Icon 6", "Icon 7", "Icon 8", "Icon 9"]
    
    let columns = [
        GridItem(.adaptive(minimum: 150), spacing: 20)
    ]
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 10) {
                Text("Liquid Glass Tests")
                    .font(.largeTitle)
                    .fontWeight(.bold)
            }
            
            // Scrollable Grid
            ScrollView {
                LazyVGrid(columns: columns, spacing: 30) {
                    ForEach(0..<iconTitles.count, id: \.self) { index in
                        VStack(spacing: 8) {
                            // Individual icon views that can be separately edited
                            Group {
                                switch index {
                                case 0: Icon1View().scaleEffect(0.47) // Scale down from 256 to ~120
                                case 1: Icon2View().scaleEffect(0.47)
                                case 2: Icon3View().scaleEffect(0.47)
                                case 3: Icon4View().scaleEffect(0.47)
                                case 4: Icon5View().scaleEffect(0.47)
                                case 5: Icon6View().scaleEffect(0.47)
                                case 6: Icon7View().scaleEffect(0.47)
                                case 7: Icon8View().scaleEffect(0.47)
                                case 8: Icon9View().scaleEffect(0.47)
                                default: Icon1View().scaleEffect(0.47)
                                }
                            }
                            .frame(width: 120, height: 120)
                            
                            Text(iconTitles[index])
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                    }
                }
                .padding()
            }
            
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
            )
            .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

// MARK: - Preview
struct LiquidGlassTestGrid_Previews: PreviewProvider {
    static var previews: some View {
        LiquidGlassTestGrid()
            .frame(minWidth: 600, minHeight: 600)
    }
}

// MARK: - Standalone Preview View
struct LiquidGlassGridView: View {
    var body: some View {
        LiquidGlassTestGrid()
            .frame(minWidth: 600, minHeight: 600)
    }
}

#Preview {
    LiquidGlassGridView()
}
