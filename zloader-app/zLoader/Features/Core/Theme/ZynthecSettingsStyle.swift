import SwiftUI

extension Binding where Value == Bool {
    /// UIKit dismisses native alerts while SwiftUI is updating their views.
    /// Publish model-owned presentation changes on the next main-queue turn.
    @MainActor func deferredPresentation() -> Binding<Bool> {
        Binding(get: { wrappedValue }, set: { value in
            DispatchQueue.main.async {
                if wrappedValue != value { wrappedValue = value }
            }
        })
    }
}

/// Semantic system roles shared by the signing settings.
enum ZynthecSettingsStyle {
    static let hostingViewTag = 77486
    static let accent = Color(red: 64 / 255, green: 181 / 255, blue: 173 / 255)
    static let background = Color(uiColor: .systemGroupedBackground)
    static let card = Color(uiColor: .secondarySystemGroupedBackground)
    static let field = Color(uiColor: .secondarySystemGroupedBackground)
    static let text = Color.primary
    static let secondary = Color.secondary
}

extension View {
    func zynthecSettingsPage() -> some View {
        self.zLoaderSettingsPage()
    }

    func zynthecSettingsRows(isInput: Bool = false) -> some View { self }
}
