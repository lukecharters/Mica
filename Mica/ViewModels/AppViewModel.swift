// ViewModels/AppViewModel.swift
// Optional app-level coordinator to host the IconViewModel
import SwiftUI

@MainActor
final class AppViewModel: ObservableObject {
    @Published var iconVM: IconViewModel = IconViewModel()
}
