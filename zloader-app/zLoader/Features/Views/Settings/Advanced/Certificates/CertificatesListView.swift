//
//  CertificatesListView.swift
//  ZLoader
//
//  Created by Magesh K on 2026-07-03.
//  Copyright © 2026 SideStore. All rights reserved.
//


import SwiftUI
import SideSign

struct CertificatesListView: View {
    @ObservedObject var viewModel: CertificatesViewModel
    var onRowTap: (ALTX509Certificate) -> Void
    var onExportP12: (ALTX509Certificate) -> Void
    var onClearKey: (ALTX509Certificate) -> Void
    var onAddKeyBin: (ALTX509Certificate) -> Void
    var onAddKeyText: (ALTX509Certificate) -> Void
    var onDelete: (ALTX509Certificate) -> Void

    private var certificates: [ALTX509Certificate] {
        viewModel.certificates.sorted {
            let order = ($0.machineName ?? $0.name).localizedCaseInsensitiveCompare($1.machineName ?? $1.name)
            return order == .orderedSame ? $0.serialNumber < $1.serialNumber : order == .orderedAscending
        }
    }

    var body: some View {
        Section {
            if certificates.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("No certificates yet", tableName: "CertificatesUI").font(.headline)
                    Text("Add a certificate using the plus button.", tableName: "CertificatesUI")
                        .foregroundStyle(ZynthecSettingsStyle.secondary)
                }
                .accessibilityIdentifier("certificates-empty")
            }
            ForEach(certificates, id: \.serialNumber) { cert in
                CertificateRowView(cert: cert, viewModel: viewModel,
                    onDetails: { onRowTap(cert) },
                    onExportP12: { onExportP12(cert) },
                    onClearKey: { onClearKey(cert) },
                    onAddKeyBin: { onAddKeyBin(cert) },
                    onAddKeyText: { onAddKeyText(cert) },
                    onDelete: { onDelete(cert) })
            }
        }.zynthecSettingsRows()
    }
}
