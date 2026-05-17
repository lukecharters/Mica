// SymbolPickerView.swift - For selecting SF Symbols
import SwiftUI

struct SymbolPickerView: View {
    @Binding var selectedSymbol: String
    @Environment(\.presentationMode) private var presentationMode
    @State private var searchText = ""
    
    // A subset of SF Symbols that work well for this application
    let symbols = [
        "gearshape.fill", "wifi", "airplane", "bell.fill", "lock.fill", "key.fill",
        "person.fill", "cloud.fill", "sun.max.fill", "moon.fill", "star.fill",
        "heart.fill", "house.fill", "network", "display", "keyboard", "phone.fill",
        "envelope.fill", "paperplane.fill", "tray.fill", "folder.fill", "doc.fill",
        "book.fill", "bookmark.fill", "tag.fill", "cart.fill", "bag.fill",
        "creditcard.fill", "clock.fill", "calendar", "gamecontroller.fill",
        "headphones", "tv.fill", "music.note", "mic.fill", "camera.fill",
        "photo.fill", "scissors", "paintbrush.fill", "hammer.fill", "wrench.fill",
        "link", "magnifyingglass", "location.fill", "map.fill", "car.fill",
        "bus.fill", "bicycle", "pawprint.fill", "leaf.fill", "flame.fill"
    ]
    
    var filteredSymbols: [String] {
        if searchText.isEmpty {
            return symbols
        } else {
            return symbols.filter { $0.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        VStack {
            TextField("Search symbols", text: $searchText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
            
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))]) {
                    ForEach(filteredSymbols, id: \.self) { symbol in
                        Button(action: {
                            selectedSymbol = symbol
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            VStack {
                                Image(systemName: symbol)
                                    .font(.system(size: 30))
                                    .frame(width: 60, height: 60)
                                    .background(selectedSymbol == symbol ? Color.blue.opacity(0.2) : Color.clear)
                                    .cornerRadius(8)
                                
                                Text(symbol)
                                    .font(.system(size: 9))
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                            }
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding()
            }
            
            HStack {
                Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
                .keyboardShortcut(.escape, modifiers: [])
                
                Spacer()
                
                Button("Select") {
                    presentationMode.wrappedValue.dismiss()
                }
                .keyboardShortcut(.return, modifiers: [])
            }
            .padding()
        }
        .frame(width: 600, height: 400)
    }
}

#Preview {
    @Previewable @State var selectedSymbol = "star.fill"
    SymbolPickerView(selectedSymbol: $selectedSymbol)
}
