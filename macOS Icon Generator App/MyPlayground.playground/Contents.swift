import PlaygroundSupport
import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            ZStack {
                RoundedRectangle(cornerRadius: 70, style: .continuous)
                    .inset(by: 25)
                    .fill(.blue.gradient)
                    .shadow(radius: 2, x: 0, y: 2.5)
                    .frame(width: 256, height: 256, alignment: .center)
                Image(systemName: "folder.fill.badge.plus")
                    .frame(width: 178, height: 178, alignment: .center)
                    .font(.system(size: 120, weight: .regular))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 3)
            }
            ZStack(alignment: .center) {
                RoundedRectangle(cornerRadius: 140, style: .continuous)
                    .inset(by: 50)
                    .fill(.blue.gradient)
                    .shadow(radius: 4, x: 0, y: 5)
                    .frame(width: 512, height: 512)
                Image(systemName: "folder.fill.badge.plus")
                    .alignmentGuide(VerticalAlignment.center) { context in context[VerticalAlignment.center] + 12
                    }
                    .frame(width: 334, height: 334, alignment: .center)
                    .font(.system(size: 240, weight: .regular))
                    .border(Color(.white))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 3)
                    
            }
        }
    }
}

let view = ContentView()

PlaygroundPage.current.setLiveView(view)

