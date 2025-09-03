import PlaygroundSupport
import SwiftUI



struct ContentView: View {
    var body: some View {
        VStack {
            ZStack {
                var displaySize: CGFloat { 256 }
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
                    .fill(Color.gray.gradient)
                    .frame(width: 256 * 0.31, height: 256 * 0.31)
                    .shadow(
                        color: .black.opacity(0.31),radius: 2, x: 0, y: 1)
                    .overlay(
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: displaySize * 0.18, weight: .regular))
                            .foregroundColor(.white)
                    )
                    .offset(x: displaySize * 0.3, y: displaySize * 0.3)
            }
        }
    }
}

let view = ContentView()

PlaygroundPage.current.setLiveView(view)
