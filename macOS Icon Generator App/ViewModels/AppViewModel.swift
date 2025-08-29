// ViewModels/AppViewModel.swift
// Optional app-level coordinator to host the IconViewModel
import SwiftUI

@MainActor
final class AppViewModel: ObservableObject {
    @Published var iconVM: IconViewModel = IconViewModel()

    // Example coordination hooks (no behavior change required for now)
    func runExportDryRun() {
        _ = IconRenderer.renderIconSafely(settings: iconVM.iconSettings)
    }
}
