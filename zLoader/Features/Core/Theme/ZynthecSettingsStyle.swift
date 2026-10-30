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

/// Shared compact settings components for the zynthec. design language.
enum ZynthecSettingsStyle {
    static let hostingViewTag = 77486
    static let radius: CGFloat = 12
    static let accent = Color(red: 64 / 255, green: 181 / 255, blue: 173 / 255)
    static let onAccent = Color(red: 16 / 255, green: 44 / 255, blue: 42 / 255)
    static let background = adaptive(light: "F0F1F3", dark: "1C1C1E")
    static let card = adaptive(light: "FFFFFF", dark: "2C2C2E")
    static let field = adaptive(light: "F5F5F7", dark: "242426")
    static let text = adaptive(light: "1D1D1F", dark: "F2F2F7")
    static let secondary = adaptive(light: "62626B", dark: "B9BBC2")
    static let border = adaptive(light: "DEDEE3", dark: "424247")

    private static func adaptive(light: String, dark: String) -> Color {
        Color(uiColor: UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light) ?? .label
        })
    }
}

extension View {
    func zynthecSettingsPage() -> some View {
        self
            .environment(\.zLoaderUsesGlass, false)
            .font(.body)
            .foregroundStyle(ZynthecSettingsStyle.text)
            .tint(ZynthecSettingsStyle.text)
            .listStyle(.plain)
            .listRowSpacing(8)
            .listSectionSpacing(20)
            .contentMargins(.horizontal, 16, for: .scrollContent)
            .scrollContentBackground(.hidden)
            .background(ZynthecSettingsStyle.background.ignoresSafeArea())
    }

    func zynthecSettingsRows(isInput: Bool = false) -> some View {
        self
            .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
            .listRowSeparator(.hidden)
            .listRowBackground(
                RoundedRectangle(cornerRadius: isInput ? 8 : ZynthecSettingsStyle.radius)
                    .fill(isInput ? ZynthecSettingsStyle.field : ZynthecSettingsStyle.card)
                    .overlay {
                        RoundedRectangle(cornerRadius: isInput ? 8 : ZynthecSettingsStyle.radius)
                            .strokeBorder(ZynthecSettingsStyle.border, lineWidth: 0.5)
                    })
    }
}

struct ZynthecActionButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 14)
            .frame(minHeight: 44)
            .background(isEnabled ? ZynthecSettingsStyle.accent : ZynthecSettingsStyle.field, in: Capsule())
            .foregroundStyle(isEnabled ? ZynthecSettingsStyle.onAccent : ZynthecSettingsStyle.secondary)
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}
