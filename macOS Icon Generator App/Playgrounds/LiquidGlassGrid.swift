//
//  LiquidGlassGrid.swift
//  macOS Icon Generator App
//
//  Created by Luke Charters on 2/9/2025.
//


import SwiftUI




struct LiquidGlassGridView: View {
    var body: some View {
        ScrollView {
            VStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 46, style: .continuous)
                        .fill(.blue.gradient)
                        .shadow(radius: 2, x: 0, y: 2.5)
                        .frame(width: 206, height: 206)
                    Image(systemName: "folder.fill.badge.plus")
                        .font(.system(size: 120, weight: .regular))
                        .frame(width: 165, height: 165, alignment: .center)
                        .foregroundColor(.white)
                        .shadow(radius: 2, x: 0, y: 2.5)
                }
            }
        }
    }
}
#Preview {
    LiquidGlassGridView()
}
