// Created by Magesh K on 9/8/26.
// Copyright © 2026 SideStore. All rights reserved.
import SwiftUI

struct ThemePickerView: View {
    var onAppIcon: (() -> Void)? = nil
    @ObservedObject private var theme = ThemeManager.shared
    @State private var selectedLanguage = AppLanguage.selected
    @State private var showsLanguageRestart = false

    var body: some View {
        List {
            Section {
                Picker(selection: $theme.appearance) {
                    ForEach(AppAppearance.allCases) { appearance in
                        Text(appearance.title, tableName: "SettingsLayout").tag(appearance)
                    }
                } label: {
                    SettingsEntryLabel(title: "Appearance", systemImage: "circle.lefthalf.filled")
                }
                .pickerStyle(.menu)
                .accessibilityIdentifier("appearance-mode")
                Picker(selection: $selectedLanguage) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.title).tag(language)
                    }
                } label: {
                    SettingsEntryLabel(title: "Language", systemImage: "globe")
                }
                .pickerStyle(.menu)
                #if !os(tvOS)
                if let onAppIcon {
                    SwiftUI.Button(action: onAppIcon) { SettingsEntryLabel(title: "Change App Icon", systemImage: "app") }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("settings-change-app-icon")
                }
                #endif
            }.zLoaderSettingsRows()
        }
        .navigationTitle("Appearance")
        .zLoaderSettingsPage()
        .accessibilityIdentifier("settings-appearance-page")
        .labelStyle(.titleAndIcon)
        .onChange(of: selectedLanguage) { _, language in
            language.save()
            showsLanguageRestart = true
        }
        .alert("Language Changed", isPresented: $showsLanguageRestart) {
            SwiftUI.Button("OK", role: .cancel) { }
        } message: {
            Text("Finish any running operation, then fully close and reopen zLoader to apply the selected language.")
        }
    }
}
