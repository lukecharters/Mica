import PlaygroundSupport
import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            ZStack {
                RoundedRectangle(cornerRadius: 46, style: .continuous)
                    .fill(.blue.gradient)
                    .shadow(radius: 2, x: 0, y: 2.5)
                    .frame(width: 206, height: 206)
                Image(systemName: "folder.fill.badge.plus")
                    .font(.system(size: 120, weight: .regular))
//                    .resizable()
//                    .aspectRatio(contentMode: .fit)
                    //.alignmentGuide(VerticalAlignment.center) { context in context[VerticalAlignment.center] + 6
                    //}
                    .frame(width: 165, height: 165, alignment: .center)
                    .foregroundColor(.white)
                    .shadow(radius: 2, x: 0, y: 2.5)
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
                    .shadow(radius: 4, x: 0, y: 5)
                    
            }
        }
    }
}

let view = ContentView()

PlaygroundPage.current.setLiveView(view)
