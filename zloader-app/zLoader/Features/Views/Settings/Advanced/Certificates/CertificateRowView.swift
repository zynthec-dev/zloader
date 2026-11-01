//
//  CertificateRowView.swift
//  ZLoader
//
//  Created by Magesh K on 2026-07-03.
//  Copyright © 2026 SideStore. All rights reserved.
//


import SwiftUI
import SideSign

struct CertificateRowView: View {
    let cert: ALTX509Certificate
    @ObservedObject var viewModel: CertificatesViewModel
    var onDetails: () -> Void
    var onExportP12: () -> Void
    var onClearKey: () -> Void
    var onAddKeyBin: () -> Void
    var onAddKeyText: () -> Void
    var onDelete: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var hasPrivateKey: Bool { viewModel.hasPrivateKey(for: cert) }
    private var isActive: Bool { cert.serialNumber == viewModel.activeSerialNumber }
    private var isExpired: Bool { cert.expiryDate <= Date() }

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 12) { summary; actions }
            } else {
                HStack(spacing: 12) { summary; actions }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("certificate-row-" + cert.serialNumber)
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(verbatim: cert.machineName ?? cert.name).font(.headline)
            HStack(spacing: 5) {
                Text("Expires", tableName: "CertificatesUI")
                Text(cert.expiryDate, format: .dateTime.day().month().year())
            }
            .font(.caption).foregroundStyle(ZynthecSettingsStyle.secondary)
            Group {
                if isExpired { Text("Expired", tableName: "CertificatesUI").foregroundStyle(.red) }
                else if isActive { Text("Active", tableName: "CertificatesUI") }
                else if !hasPrivateKey { Text("Private key missing", tableName: "CertificatesUI") }
                else { Text("Ready to use", tableName: "CertificatesUI") }
            }
            .font(.caption).foregroundStyle(ZynthecSettingsStyle.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var actions: some View {
        HStack(spacing: 4) {
            if hasPrivateKey && (!isExpired || isActive) {
                SwiftUI.Button {
                    if isActive { viewModel.deactivateActiveCertificate(showConfirmation: false) }
                    else { viewModel.makeCertificateActive(cert, showConfirmation: false) }
                } label: {
                    if isActive { Label { Text("Active", tableName: "CertificatesUI") } icon: { Image(systemName: "checkmark") } }
                    else { Text("Use", tableName: "CertificatesUI") }
                }
                .buttonStyle(.borderedProminent)
                .accessibilityLabel(Text(isActive ? "Deactivate certificate" : "Use certificate", tableName: "CertificatesUI"))
                .accessibilityIdentifier("certificate-use-" + cert.serialNumber)
                .disabled(viewModel.isLoading)
            }
            Menu {
                SwiftUI.Button(action: onDetails) { Label { Text("Details", tableName: "CertificatesUI") } icon: { Image(systemName: "info.circle") } }
                if hasPrivateKey {
                    SwiftUI.Button(action: onExportP12) { Label { Text("Export as P12…", tableName: "CertificatesUI") } icon: { Image(systemName: "square.and.arrow.up") } }
                } else {
                    SwiftUI.Button(action: onAddKeyBin) { Label { Text("Add private key from file…", tableName: "CertificatesUI") } icon: { Image(systemName: "key") } }
                    SwiftUI.Button(action: onAddKeyText) { Text("Paste private key…", tableName: "CertificatesUI") }
                }
                SwiftUI.Button {
                    CertificateExporter.sharePublicCertAsDER(cert, onShare: { viewModel.shareURL = $0 }) { viewModel.errorMessage = $0 }
                } label: { Text("Export public certificate…", tableName: "CertificatesUI") }
                if hasPrivateKey {
                    SwiftUI.Button(role: .destructive, action: onClearKey) { Text("Remove private key…", tableName: "CertificatesUI") }
                }
                if viewModel.isCertificateLocallyCached(cert) {
                    SwiftUI.Button(role: .destructive, action: onDelete) { Label { Text("Delete locally…", tableName: "CertificatesUI") } icon: { Image(systemName: "trash") } }
                }
            } label: {
                Image(systemName: "ellipsis").frame(minWidth: 44, minHeight: 44)
                    .foregroundStyle(ZynthecSettingsStyle.text)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Certificate actions", tableName: "CertificatesUI"))
            .accessibilityIdentifier("certificate-actions-" + cert.serialNumber)
        }
    }
}
