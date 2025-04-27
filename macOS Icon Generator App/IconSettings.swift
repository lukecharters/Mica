// IconSettings.swift - Data model for our icon configuration
import SwiftUI

struct IconSettings: Equatable {
    var symbolName: String = "gearshape.fill"
    var primaryColor: Color = .blue
    var secondaryColor: Color = .purple
    var useCustomColors: Bool = false
    var customPrimaryColor: Color = .blue
    var customSecondaryColor: Color = .purple
    var exportSize: CGFloat = 256
    var exportRetinaSize: Bool = true
    
    var gradientColors: [Color] {
        if useCustomColors {
            return [customPrimaryColor, customSecondaryColor]
        } else {
            return [primaryColor, secondaryColor]
        }
    }
    
    var finalExportSize: CGFloat {
        return exportRetinaSize ? exportSize * 2 : exportSize
    }
}