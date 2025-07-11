// IconPreview.swift - Displays a preview of our icon
import SwiftUI

struct IconPreview: View {
    let settings: IconSettings
    
    var body: some View {
        // Use the shared IconContentView with default 256pt size for standard preview
        IconContentView(settings: settings, displaySize: 256)
    }
}