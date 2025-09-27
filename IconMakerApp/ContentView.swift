import SwiftUI

  

@main

struct IconMakerApp: App {

    var body: some Scene {

        WindowGroup {

            ContentView()

        }

    }

}

  

struct ContentView: View {

    @State private var selectedSymbol = "gear"

    @State private var selectedGradient = 0

    @State private var iconSize: CGFloat = 120

    let gradients: [AnyShapeStyle] = [
        AnyShapeStyle(.blue.gradient),
        AnyShapeStyle(.purple.gradient),
        AnyShapeStyle(.orange.gradient),
        AnyShapeStyle(.green.gradient),
        AnyShapeStyle(.yellow.gradient),
        AnyShapeStyle(.indigo.gradient),
        AnyShapeStyle(.pink.gradient),
        AnyShapeStyle(.red.gradient)
    ]

    let popularSymbols = [
        "square.fill",
        "square.and.arrow.up",
        "square.and.arrow.up.trianglebadge.exclamationmark",
        "folder.fill.badge.plus",
        "doc.text.magnifyingglass",
        "gearshape.fill",
        "bell.and.waves.left.and.right.fill",
        "person.crop.circle",
        "person.crop.circle.badge.plus",
        "phone.fill",
        "phone.fill.badge.checkmark",
        "gear", "person.fill", "bell.fill", "lock.fill", "camera.fill",

        "music.note","folder.fill.badge.plus", "gamecontroller.fill", "globe", "heart.fill", "star.fill",

        "house.fill", "car.fill", "airplane", "phone.fill", "message.fill",

        "mail.fill", "calendar", "camera", "photo.fill", "video.fill"

    ]

    var body: some View {

        NavigationStack {

            ScrollView {

                VStack(spacing: 30) {

                    // Icon Preview

                    VStack(spacing: 16) {

                        Text("Preview")

                            .font(.headline)

                            .frame(maxWidth: .infinity, alignment: .leading)

                        RoundedRectangle(cornerRadius: iconSize * 0.22)

                            .fill(gradients[selectedGradient])

                            .frame(width: iconSize, height: iconSize)

                            .overlay(

                                Image(systemName: selectedSymbol)
                                    //.font(.title)

                                    .font(.system(size: iconSize * 0.5, weight: .medium))

                                    .foregroundStyle(.white)

                            )

                            .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)

                    }

                    // Size Slider

                    VStack(spacing: 16) {

                        Text("Size")

                            .font(.headline)

                            .frame(maxWidth: .infinity, alignment: .leading)

                        Slider(value: $iconSize, in: 80...200) {

                            Text("Size")

                        } minimumValueLabel: {

                            Image(systemName: "minus")

                                .foregroundStyle(.secondary)

                        } maximumValueLabel: {

                            Image(systemName: "plus")

                                .foregroundStyle(.secondary)

                        }

                    }

                    // Gradient Selection

                    VStack(spacing: 16) {

                        Text("Gradient")

                            .font(.headline)

                            .frame(maxWidth: .infinity, alignment: .leading)

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {

                            ForEach(gradients.indices, id: \.self) { index in

                                RoundedRectangle(cornerRadius: 12)

                                    .fill(gradients[index])

                                    .frame(height: 50)

                                    .overlay(

                                        RoundedRectangle(cornerRadius: 12)

                                            .strokeBorder(

                                                selectedGradient == index ? Color.primary : Color.clear,

                                                lineWidth: 3

                                            )

                                    )

                                    .onTapGesture {

                                        selectedGradient = index

                                    }

                                    .sensoryFeedback(.selection, trigger: selectedGradient)

                            }

                        }

                    }

                    // Symbol Selection

                    VStack(spacing: 16) {

                        Text("Symbol")

                            .font(.headline)

                            .frame(maxWidth: .infinity, alignment: .leading)

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {

                            ForEach(popularSymbols, id: \.self) { symbol in

                                RoundedRectangle(cornerRadius: 8)

                                    .fill(Color.secondary.opacity(0.1))

                                    .frame(height: 50)

                                    .overlay(

                                        Image(systemName: symbol)

                                            .font(.title2)

                                            .foregroundStyle(selectedSymbol == symbol ? .primary : .secondary)

                                    )

                                    .overlay(

                                        RoundedRectangle(cornerRadius: 8)

                                            .strokeBorder(

                                                selectedSymbol == symbol ? Color.primary : Color.clear,

                                                lineWidth: 2

                                            )

                                    )

                                    .onTapGesture {

                                        selectedSymbol = symbol

                                    }

                                    .sensoryFeedback(.selection, trigger: selectedSymbol)

                            }

                        }

                    }

                }

                .padding()

            }

            .navigationTitle("Icon Maker")

        }

    }

}

#Preview {
    ContentView()
}
