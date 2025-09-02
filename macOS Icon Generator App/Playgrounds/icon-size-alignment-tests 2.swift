import SwiftUI


struct textsymbolTestView: View {
    let symbolName = "folder.fill.badge.plus"
    
    var body: some View {
        VStack {
            ZStack {
                RoundedRectangle(cornerRadius: 46, style: .continuous)
                    .fill(.blue.gradient)
                    .shadow(radius: 2, x: 0, y: 2.5)
                    .frame(width: 206, height: 206)
                
                (Image(systemName: symbolName))
                    .font(.system(size: 120, weight: .regular))

                    //.minimumScaleFactor(0.5)
                    //.lineLimit(1)
                    .frame(width: 165, height: 165)
                    .foregroundColor(.white)
                    .scaleEffect(x: 0.5, y: 0.5, anchor: .center)
                    .shadow(radius: 2, x: 0, y: 2.5)
            }
            .frame(width: 256, height: 256)
        }
    }
}

#Preview {
    textsymbolTestView()
}
