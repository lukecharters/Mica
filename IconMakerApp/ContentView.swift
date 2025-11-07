import SwiftUI

struct ContentView: View {
    @State private var selectedSymbol = "gear"
    @State private var selectedGradient = 0
    @State private var iconSize: CGFloat = 120
    @State private var symbolSize: CGFloat = 0.5
    @State private var customSymbol = ""
    @State private var renderingMode = "monochrome"
    @State private var monochromeColor = Color.white
    @State private var hierarchicalColor = Color.white
    @State private var paletteColor1 = Color.white
    @State private var paletteColor2 = Color.white.opacity(0.6)
    @State private var paletteColor3 = Color.white.opacity(0.3)
    @State private var glassEffectMode = "identity"
    @State private var glassTintColor = Color.blue
    
    let renderingModes = ["monochrome", "hierarchical", "palette", "multicolor"]
    let glassEffectModes = ["identity", "regular", "clear", "regular.tint"]
    let systemColors: [String: Color] = {
        var dict = [String: Color]()
        dict["blue"] = .blue
        dict["purple"] = .purple
        dict["pink"] = .pink
        dict["red"] = .red
        dict["orange"] = .orange
        dict["yellow"] = .yellow
        dict["green"] = .green
        dict["teal"] = .teal
        dict["cyan"] = .cyan
        dict["indigo"] = .indigo
        dict["mint"] = .mint
        dict["brown"] = .brown
        return dict
    }()
    
    let gradients: [[Color]] = {
        var array = [[Color]]()
        array.append([.blue, .cyan])
        array.append([.purple, .pink])
        array.append([.orange, .red])
        array.append([.green, .mint])
        array.append([.yellow, .orange])
        array.append([.indigo, .blue])
        array.append([.pink, .purple])
        array.append([.red, .orange])
        return array
    }()
    
    let popularSymbols = [
        "gear", "person.fill", "bell.fill", "lock.fill", "camera.fill",
        "music.note", "gamecontroller.fill", "globe", "heart.fill", "star.fill",
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
                            .fill(
                                (glassEffectMode == "regular" || glassEffectMode == "clear" || glassEffectMode == "regular.tint") ?
                                AnyShapeStyle(Color.clear) :
                                AnyShapeStyle(LinearGradient(
                                    colors: gradients[selectedGradient],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ))
                            )
                            .frame(width: iconSize, height: iconSize)
                            .overlay(
                               Group {
                                    if #available(iOS 26.0, *), glassEffectMode != "identity" {
                                        ZStack {
                                            let image = Image(systemName: customSymbol.isEmpty ? selectedSymbol : customSymbol)
                                                .font(.system(size: iconSize * symbolSize, weight: .medium))
                                            
                                            switch renderingMode {
                                            case "monochrome":
                                                image.symbolRenderingMode(.monochrome)
                                                    .foregroundStyle(monochromeColor)
                                            case "hierarchical":
                                                image.symbolRenderingMode(.hierarchical)
                                                    .foregroundStyle(hierarchicalColor)
                                            case "palette":
                                                image.symbolRenderingMode(.palette)
                                                    .foregroundStyle(paletteColor1, paletteColor2, paletteColor3)
                                            case "multicolor":
                                                image.symbolRenderingMode(.multicolor)
                                                    .foregroundStyle(monochromeColor)
                                            default:
                                                image.foregroundStyle(monochromeColor)
                                            }
                                        }
                                        .frame(width: iconSize, height: iconSize)
                                        .glassEffect(
                                            glassEffectMode == "regular" ? .regular :
                                            glassEffectMode == "clear" ? .clear :
                                            glassEffectMode == "regular.tint" ? .regular.tint(glassTintColor) : .regular,
                                            in: .rect (cornerRadius: iconSize * 0.1)
                                        )
                                    } else {
                                        let image = Image(systemName: customSymbol.isEmpty ? selectedSymbol : customSymbol)
                                            .font(.system(size: iconSize * symbolSize, weight: .medium))
                                        
                                        switch renderingMode {
                                        case "monochrome":
                                            image.symbolRenderingMode(.monochrome)
                                                .foregroundStyle(monochromeColor)
                                        case "hierarchical":
                                            image.symbolRenderingMode(.hierarchical)
                                                .foregroundStyle(hierarchicalColor)
                                        case "palette":
                                            image.symbolRenderingMode(.palette)
                                                .foregroundStyle(paletteColor1, paletteColor2, paletteColor3)
                                        case "multicolor":
                                            image.symbolRenderingMode(.multicolor)
                                                .foregroundStyle(monochromeColor)
                                        default:
                                            image.foregroundStyle(monochromeColor)
                                        }
                                    }
                                }
                            )
                            .clipShape(RoundedRectangle(cornerRadius: iconSize * 0.22))
                            .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                    }
                    
                    // Size Slider
                    VStack(spacing: 16) {
                        Text("Icon Size")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Slider(value: $iconSize, in: 80...200) {
                            Text("Icon Size")
                        } minimumValueLabel: {
                            Image(systemName: "minus")
                                .foregroundStyle(.secondary)
                        } maximumValueLabel: {
                            Image(systemName: "plus")
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    // Symbol Size Slider
                    VStack(spacing: 16) {
                        Text("Symbol Size")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Slider(value: $symbolSize, in: 0.2...0.8) {
                            Text("Symbol Size")
                        } minimumValueLabel: {
                            Image(systemName: "textformat.size.smaller")
                                .foregroundStyle(.secondary)
                        } maximumValueLabel: {
                            Image(systemName: "textformat.size.larger")
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    // Custom Symbol Input
                    VStack(spacing: 16) {
                        Text("Custom Symbol")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        TextField("Enter SF Symbol name", text: $customSymbol)
                            .textFieldStyle(.roundedBorder)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                       
                        if !customSymbol.isEmpty {
                            Text("Using: \(customSymbol)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                               .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    
                    // Glass Effect Mode
                    VStack(spacing: 16) {
                        Text("Glass Effect")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Picker("Glass Effect", selection: $glassEffectMode) {
                            ForEach(glassEffectModes, id: \.self) { mode in
                                Text(mode).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        
                        if glassEffectMode == "regular.tint" {
                            VStack(spacing: 12) {
                                Text("Glass Tint Color")
                                    .font(.subheadline)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                                    ForEach(Array(systemColors.keys.sorted()), id: \.self) { colorName in
                                        Circle()
                                            .fill(systemColors[colorName] ?? .blue)
                                            .frame(height: 44)
                                            .overlay(
                                                Circle()
                                                    .strokeBorder(
                                                        glassTintColor == (systemColors[colorName] ?? .blue) ? Color.primary : Color.clear,
                                                        lineWidth: 3
                                                    )
                                            )
                                            .onTapGesture {
                                                glassTintColor = systemColors[colorName] ?? .blue
                                            }
                                    }
                                }
                            }
                        }
                    }
                    
                    // Rendering Mode
                    VStack(spacing: 16) {
                        Text("Rendering Mode")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Picker("Rendering Mode", selection: $renderingMode) {
                            ForEach(renderingModes, id: \.self) { mode in
                                Text(mode.capitalized).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        
                        // Color pickers based on rendering mode
                        switch renderingMode {
                        case "monochrome":
                            ColorPicker("Symbol Color", selection: $monochromeColor)
                        case "hierarchical":
                            ColorPicker("Symbol Color", selection: $hierarchicalColor)
                        case "palette":
                            VStack(spacing: 12) {
                                ColorPicker("Primary Color", selection: $paletteColor1)
                                ColorPicker("Secondary Color", selection: $paletteColor2)
                                ColorPicker("Tertiary Color", selection: $paletteColor3)
                            }
                        case "multicolor":
                            ColorPicker("Tint Color", selection: $monochromeColor)
                        default:
                            EmptyView()
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
                                    .fill(LinearGradient(
                                        colors: gradients[index],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ))
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
