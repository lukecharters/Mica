// Testing size and alignment of SF Symbols
import AppKit
import SwiftUI

struct symbolTestView: View {
    let symbolName = "folder.fill.badge.plus"
    @State private var idealFontSize: CGFloat = 135
       @State private var measuredSize: CGSize = .zero
    @State private var frameSize: CGFloat = 208
       var calculatedFontSize: CGFloat {
           if measuredSize.width > frameSize || measuredSize.height > frameSize {
               let scaleFactor = min(frameSize / max(measuredSize.width, 1),
                                     frameSize / max(measuredSize.height, 1))
               return idealFontSize * scaleFactor //* 0.95 // 0.95 for safety margin
           }
           return idealFontSize
       }
    
    var body: some View {
        VStack {
            ZStack(alignment: .center) {
                RoundedRectangle(cornerRadius: 46, style: .continuous)
                                        .fill(.blue.gradient)
                                        .shadow(radius: 2, x: 0, y: 2.5)
                                        .frame(width: 206, height: 206) 
// Actual icon size
// MARK: Original
//                Image(systemName: symbolName)
//                    .font(.system(size: 135, weight: .regular))
//                    .minimumScaleFactor(0.5)
//                    //.alignmentGuide(VerticalAlignment.center) { context in context[VerticalAlignment.center] + 2}
//                    .frame(width: 165, height: 165, alignment: .center) // 80% of 206
//                    .foregroundColor(.white)
//                    .shadow(radius: 2, x: 0, y: 2.5)
//                    .background(RoundedRectangle(cornerRadius: 46, style: .continuous)
//                        .fill(.blue.gradient)
//                        .shadow(radius: 2, x: 0, y: 2.5)
//                        .frame(width: 206, height: 206) )
                
                
// MARK: resizable
//                Image(systemName: symbolName)
//                    .resizable()
//                    .scaledToFit()
//                    .scaleEffect(x: 0.8, y: 0.8, anchor: .center)
//                    .frame(maxWidth: 208, maxHeight: 208, alignment: .center) // 80% of 206
//                   //.frame(maxWidth: 165, maxHeight: 165)
//                    .foregroundColor(.white)
//                    .shadow(radius: 2, x: 0, y: 2.5)
                
                
// MARK: overlay
//                Color.clear
//                    .frame(width: 165, height: 165)
//                    .overlay(
//                        Image(systemName: symbolName)
//                            .resizable()
//                            .aspectRatio(contentMode: .fit)
//                            .foregroundColor(.white)
//                            .shadow(radius: 2, x: 0, y: 2.5)
//                    )
// MARK: Geometry Reader
//                GeometryReader { geometry in
//                            Image(systemName: "gearshape.fill")
//                                .resizable()
//                                .aspectRatio(contentMode: .fit)
//                                .foregroundColor(.white)
//                                .shadow(radius: 2, x: 0, y: 2.5)
//                                .frame(width: geometry.size.width, height: geometry.size.height)
//                                .position(x: geometry.size.width / 2, // Add small offset here
//                                          y: geometry.size.height / 2)                }
//                .frame(width: 165, height: 165) // 80% of 206
//MARK: Max size
//                Image(systemName: symbolName)
//                    .font(.system(size: 135, weight: .regular))
//                    .imageScale(.large)
//                    .minimumScaleFactor(0.01) // Allow scaling down as needed
//                    .aspectRatio(contentMode: .fit)
//                    .frame(maxWidth: 165, maxHeight: 165)
//                    .foregroundColor(.white)
//                    .shadow(radius: 2, x: 0, y: 2.5)
//MARK: View that fits
//                ViewThatFits {
//                    Image(systemName: symbolName)
//                        .font(.system(size: 120, weight: .regular))
//                        //.resizable()
//                        //.aspectRatio(contentMode: .fit)
//                        //.imageScale(.large)
//                        .frame(maxWidth: 165, maxHeight: 165)
//                        .foregroundColor(.white)
//                        .shadow(radius: 2, x: 0, y: 2.5)
//                    
//                    Image(systemName: symbolName)
//                        .font(.system(size: 120, weight: .regular))
//                        .frame(maxWidth: 165, maxHeight: 165)
//                        .foregroundColor(.white)
//                        .shadow(radius: 2, x: 0, y: 2.5)
//                    
//                    Image(systemName: symbolName)
//                        .font(.system(size: 100, weight: .regular))
//                        .frame(maxWidth: 165, maxHeight: 165)
//                        .foregroundColor(.white)
//                        .shadow(radius: 2, x: 0, y: 2.5)
//                }
//MARK: Double render
//Invisible measuring pass
                Image(systemName: symbolName)
                    .font(.system(size: idealFontSize, weight: .regular))
                    .imageScale(.large)
                    .background(
                        GeometryReader { geometry in
                            Color.clear
                                .onAppear {
                                    measuredSize = geometry.size
                                }
                        }
                    )
                    .opacity(0)
//                
                // Visible render with calculated size
                Image(systemName: symbolName)
                    .font(.system(size: calculatedFontSize, weight: .regular))
                    .imageScale(.medium)
                    .foregroundColor(.white)
                    .shadow(radius: 2, x: 0, y: 2.5)
                    .frame(width: frameSize, height: frameSize)
//
//                
//                
            }
            .frame(width: 256, height: 256) // Full icon canvas size
        }
    }
}



//let view = symbolTestView()

#Preview {
    symbolTestView()
}
