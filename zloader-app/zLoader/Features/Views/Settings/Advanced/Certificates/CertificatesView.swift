//
//  CertificatesView.swift
//  ZLoader
//
//  Created by Magesh K on 2026-06-29.
//  Copyright © 2026 SideStore. All rights reserved.
//

import SwiftUI
import SideSign
import UniformTypeIdentifiers

struct CertificatesView: View {
    weak var presentingViewController: UIViewController?

    @StateObject private var viewModel = CertificatesViewModel()

    private var allowedImportTypes: [UTType] {
        ["p12", "pfx", "pkcs12", "der", "cer", "crt", "pem"].compactMap { UTType(filenameExtension: $0) }
    }
    private var allowedKeyImportTypes: [UTType] {
        ["key", "pem", "der"].compactMap { UTType(filenameExtension: $0) }
    }

    @State private var requests: [LocalKeyMaterialStore.Item] = []
    @State private var showRequestSheet = false
    @State private var requestDocument: CertificateRequestDocument?
    @State private var requestFilename = "SigningRequest.csr"
    @State private var exportRequest = false
    @State private var requestToDelete: LocalKeyMaterialStore.Item?
    @State private var detailCertificate: ALTX509Certificate?
    @State private var showPortalCertificates = false
    @State private var showKeyMaterials = false
    @State private var showCreateSheet            = false
    @State private var showFileImporter           = false
    @State private var showDeleteConfirmation     = false
    @State private var showExportPasswordPrompt   = false
    @State private var showClearKeyConfirmation   = false
    @State private var hasInitialLoaded           = false

    @State private var exportPasswordInput   = ""
    @State private var importPasswordInput = ""
    @State private var fileImportMode: FileImportMode       = .certificate
    @State private var keyTextImportItem: KeyTextImportItem? = nil
    @State private var privateKeyTextInput   = ""


    @State private var certificateToDelete:      ALTX509Certificate? = nil
    @State private var certificateToExport:      ALTX509Certificate? = nil
    @State private var certificateToAddKeyFor:   ALTX509Certificate? = nil
    @State private var certificateToClearKeyFor: ALTX509Certificate? = nil

    var body: some View {
        ZStack {
            List {
                CertificatesListView(
                    viewModel: viewModel,
                    onRowTap:     { pushDetailView(for: $0) },
                    onExportP12:  { cert in
                        certificateToExport = cert
                        exportPasswordInput = ""
                        showExportPasswordPrompt = true
                    },
                    onClearKey:   { cert in
                        certificateToClearKeyFor = cert
                        showClearKeyConfirmation = true
                    },
                    onAddKeyBin:  { cert in
                        importPrivateKeyAction(for: cert)
                    },
                    onAddKeyText: { cert in
                        keyTextImportItem = KeyTextImportItem(id: cert.serialNumber, cert: cert)
                    },
                    onDelete: { certificateToDelete = $0; showDeleteConfirmation = true }
                )
                savedRequests
                Section {
                    NavigationLink { SigningIdentitiesView() } label: {
                        Label {
                            Text("Signing & profiles", tableName: "CertificatesUI")
                        } icon: { Image(systemName: "signature").foregroundStyle(Color(uiColor: .settingsSymbol)) }
                    }.accessibilityIdentifier("certificates-signing-configuration")
                }.zynthecSettingsRows()
            }
            .refreshable {
                await withCheckedContinuation { continuation in
                    viewModel.loadCertificates(presentingViewController: presentingViewController, isPullToRefresh: true) {
                        continuation.resume()
                    }
                }
            }
            .navigationTitle("Certificates")
            .navigationBarTitleDisplayMode(.inline)
        .zynthecSettingsPage()
        .labelStyle(.titleAndIcon)
        .environment(\.settingsEntryIconsVisible, true)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        SwiftUI.Button { showRequestSheet = true } label: {
                            Label { Text("Request certificate…", tableName: "CertificatesUI") } icon: { Image(systemName: "doc.badge.plus") }
                        }.accessibilityIdentifier("certificates-request")
                        SwiftUI.Button { showCreateSheet = true } label: {
                            Label { Text("Create Apple certificate…", tableName: "CertificatesUI") } icon: { Image(systemName: "plus.rectangle") }
                        }.accessibilityIdentifier("certificates-create-apple")
                        SwiftUI.Button { importCertificatesAction() } label: {
                            Label { Text("Import from file…", tableName: "CertificatesUI") } icon: { Image(systemName: "square.and.arrow.down") }
                        }.accessibilityIdentifier("certificates-import-file")
                        SwiftUI.Button { showPortalCertificates = true } label: {
                            Label { Text("Import from Apple Portal…", tableName: "CertificatesUI") } icon: { Image(systemName: "apple.logo") }
                        }.accessibilityIdentifier("certificates-import-portal")
                    } label: { Image(systemName: "plus") }
                    .accessibilityLabel(Text("Add certificate", tableName: "CertificatesUI"))
                    .accessibilityIdentifier("certificates-add")
                }
            }
            .onAppear {
                guard !hasInitialLoaded else { return }
                hasInitialLoaded = true
                reloadRequests()
                viewModel.loadCertificates(presentingViewController: nil)
            }

            if viewModel.isLoading { LoadingOverlay() }
        }
        .alert("Error", isPresented: $viewModel.showErrorAlert.deferredPresentation()) {
            SwiftUI.Button("OK", role: .cancel) { DispatchQueue.main.async { viewModel.errorMessage = nil } }
        } message: {
            Text(viewModel.errorMessage ?? "An unknown error occurred.")
        }
        .navigationDestination(isPresented: Binding(get: { detailCertificate != nil }, set: { if !$0 { detailCertificate = nil } })) {
            if let detailCertificate { CertificateDetailView(certificate: detailCertificate, viewModel: viewModel) }
        }
        .sheet(isPresented: $showRequestSheet, onDismiss: reloadRequests) {
            CertificateRequestView(onCreated: reloadRequests)
        }
        .fileExporter(isPresented: $exportRequest, document: requestDocument, contentType: .data, defaultFilename: requestFilename) { result in
            if case .failure(let error) = result { viewModel.errorMessage = error.localizedDescription }
            requestDocument = nil
        }
        .alert(Text("Delete request?", tableName: "CertificatesUI"), isPresented: Binding(get: { requestToDelete != nil }, set: { if !$0 { requestToDelete = nil } })) {
            SwiftUI.Button(role: .destructive) {
                if let requestToDelete {
                    do { try LocalKeyMaterialStore.delete(requestToDelete); reloadRequests() }
                    catch { viewModel.errorMessage = error.localizedDescription }
                }
                requestToDelete = nil
            } label: { Text("Delete", tableName: "CertificatesUI") }
            SwiftUI.Button(role: .cancel) { requestToDelete = nil } label: { Text("Cancel", tableName: "CertificatesUI") }
        } message: { Text("The local request and its stored key will be removed. Certificates already imported are kept.", tableName: "CertificatesUI") }
        .sheet(isPresented: $showPortalCertificates, onDismiss: { viewModel.loadCertificates(presentingViewController: nil) }) {
            NavigationStack {
                AccountCertificatesView()
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            SwiftUI.Button { showPortalCertificates = false } label: { Text("Done", tableName: "CertificatesUI") }
                        }
                    }
            }
        }
        .sheet(isPresented: $showKeyMaterials) {
            NavigationStack { LocalKeyMaterialView() }
        }
        .sheet(isPresented: $showCreateSheet) {
            CreateCertificateSheetView(
                viewModel: viewModel,
                presentingViewController: presentingViewController,
                isPresented: $showCreateSheet
            )
        }
        .alert("Delete Certificate", isPresented: $showDeleteConfirmation) {
            SwiftUI.Button("Delete", role: .destructive) {
                if let cert = certificateToDelete {
                    DispatchQueue.main.async { viewModel.deleteCertificate(cert) }
                }
            }
            SwiftUI.Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete this certificate locally? This will remove it from the cached local store.")
        }
        .onChange(of: viewModel.showPasswordPromptForImport) { _, _ in importPasswordInput = "" }
        .alert("Import Certificate Password", isPresented: importPasswordPrompt) {
            SecureField("Password", text: $importPasswordInput)
            SwiftUI.Button("Import") {
                // Allow the native alert to finish its view update before
                // publishing the imported certificate list and next alert.
                let password = importPasswordInput
                DispatchQueue.main.async {
                    viewModel.importPasswordInput = password
                    viewModel.submitImportPassword()
                }
            }
            SwiftUI.Button("Cancel", role: .cancel) {
                DispatchQueue.main.async { viewModel.cancelImport() }
            }
        } message: {
            Text("Enter the password to decrypt the imported certificate file.\n\nFile: \(viewModel.currentImportFilename)")
        }
        .alert("Success", isPresented: $viewModel.showAlert.deferredPresentation()) {
            SwiftUI.Button("OK", role: .cancel) { DispatchQueue.main.async { viewModel.alertMessage = nil } }
        } message: {
            Text(viewModel.alertMessage ?? "")
        }
        .alert("Import Summary", isPresented: $viewModel.showImportSummary.deferredPresentation()) {
            if viewModel.importFailedCount > 0 {
                SwiftUI.Button("Show Failed") {
                    DispatchQueue.main.async {
                        viewModel.showFailuresAlert = true
                    }
                }
                SwiftUI.Button("OK", role: .cancel) {}
            } else {
                SwiftUI.Button("OK", role: .cancel) {}
            }
        } message: {
            Text(viewModel.importSummaryMessage)
        }
        .sheet(isPresented: $viewModel.showFailuresAlert.deferredPresentation()) {
            NavigationStack {
                List {
                    ForEach(viewModel.failedImportsList, id: \.self) { failure in
                        Text(failure)
                            .font(.system(.footnote, design: .monospaced))
                            .foregroundColor(.red)
                    }
                }
                .navigationTitle("Import Failures")
        .zynthecSettingsPage()
        .labelStyle(.titleAndIcon)
        .environment(\.settingsEntryIconsVisible, true)
                #if !os(tvOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        SwiftUI.Button("Done") {
                            viewModel.showFailuresAlert = false
                        }
                    }
                }
            }
        }
        .alert("Export Certificate Password", isPresented: $showExportPasswordPrompt) {
            SecureField("Password", text: $exportPasswordInput)
            SwiftUI.Button("Export") {
                if let cert = certificateToExport, let signable = viewModel.getSignableCertificate(for: cert.serialNumber) {
                    CertificateExporter.shareP12(signable, password: exportPasswordInput, onShare: { viewModel.shareURL = $0 }) { viewModel.errorMessage = $0 }
                }
            }
            SwiftUI.Button("Cancel", role: .cancel) {}
        } message: {
            Text("Set a password to encrypt the exported .p12 certificate file.")
        }
        .alert("Clear Private Key", isPresented: $showClearKeyConfirmation) {
            if let cert = certificateToClearKeyFor {
                SwiftUI.Button("Clear Key", role: .destructive) {
                    DispatchQueue.main.async { viewModel.clearPrivateKey(for: cert) }
                    certificateToClearKeyFor = nil
                }
            }
            SwiftUI.Button("Cancel", role: .cancel) { certificateToClearKeyFor = nil }
        } message: {
            if let cert = certificateToClearKeyFor {
                Text("This will clear the locally stored private key of this certificate.\n\nName: \(cert.name)\nS/N: \(cert.serialNumber)")
            }
        }
        #if !os(tvOS)
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: fileImportMode == .certificate ? allowedImportTypes : allowedKeyImportTypes,
            allowsMultipleSelection: fileImportMode == .certificate
        ) { result in
            switch result {
            case .success(let urls):
                switch fileImportMode {
                case .certificate:
                    viewModel.startBulkImport(urls: urls)
                case .privateKey:
                    if let url = urls.first, let cert = certificateToAddKeyFor {
                        _ = url.startAccessingSecurityScopedResource()
                        defer { url.stopAccessingSecurityScopedResource() }
                        do {
                            viewModel.importPrivateKey(data: try Data(contentsOf: url), for: cert)
                        } catch {
                            viewModel.errorMessage = NSLocalizedString("Failed to read private key: ", comment: "") + error.localizedDescription
                        }
                    }
                }
            case .failure(let error):
                let type = fileImportMode == .certificate ? "files" : "private key"
                viewModel.errorMessage = "Failed to select \(type): " + error.localizedDescription
            }
        }
        #endif
        .sheet(item: $keyTextImportItem) { item in
            PrivateKeyTextInputView(
                text: $privateKeyTextInput,
                cert: item.cert,
                viewModel: viewModel,
                allowedKeyImportTypes: allowedKeyImportTypes,
                onCancel: {
                    keyTextImportItem = nil
                    privateKeyTextInput = ""
                }
            )
        }
        .sheet(isPresented: Binding<Bool>(
            get: { viewModel.shareURL != nil },
            set: { if !$0 { DispatchQueue.main.async { viewModel.shareURL = nil } } }
        )) {
            if let url = viewModel.shareURL {
                ActivityViewController(activityItems: [url])
            }
        }
    }

    private var importPasswordPrompt: Binding<Bool> {
        Binding(get: { viewModel.showPasswordPromptForImport }, set: { visible in
            // UIKit may dismiss the secure field during a SwiftUI update.
            // Avoid publishing a redundant/synchronous model change there.
            DispatchQueue.main.async {
                if viewModel.showPasswordPromptForImport != visible {
                    viewModel.showPasswordPromptForImport = visible
                }
            }
        })
    }

    @ViewBuilder private var savedRequests: some View {
                if !requests.isEmpty {
                    Section {
                        ForEach(requests) { request in
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(verbatim: request.name).font(.headline)
                                    Text("Signing request", tableName: "CertificatesUI")
                                        .font(.caption).foregroundStyle(ZynthecSettingsStyle.secondary)
                                }.frame(maxWidth: .infinity, alignment: .leading)
                                SwiftUI.Button {
                                    if let data = request.request {
                                        requestDocument = CertificateRequestDocument(data: data)
                                        requestFilename = request.name.replacingOccurrences(of: "/", with: "_") + ".csr"
                                        exportRequest = true
                                    }
                                } label: { Image(systemName: "square.and.arrow.up").frame(minWidth: 44, minHeight: 44) }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel(Text("Export request", tableName: "CertificatesUI"))
                                    .accessibilityIdentifier("certificate-request-export-" + request.id)
                                Menu {
                                    SwiftUI.Button { showKeyMaterials = true } label: { Text("Manage matching key…", tableName: "CertificatesUI") }
                                    SwiftUI.Button(role: .destructive) { requestToDelete = request } label: { Text("Delete request…", tableName: "CertificatesUI") }
                                } label: { Image(systemName: "ellipsis").frame(minWidth: 44, minHeight: 44) }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel(Text("Request actions", tableName: "CertificatesUI"))
                                    .accessibilityIdentifier("certificate-request-actions-" + request.id)
                            }
                            .accessibilityElement(children: .contain)
                            .accessibilityIdentifier("certificate-request-row-" + request.id)
                        }
                    } header: { Text("Requests", tableName: "CertificatesUI") }
                        .zynthecSettingsRows()
                }
    }

    private func pushDetailView(for cert: ALTX509Certificate) {
        detailCertificate = cert
    }

    private func reloadRequests() {
        do { requests = try LocalKeyMaterialStore.list().filter { $0.request != nil } }
        catch { viewModel.errorMessage = error.localizedDescription }
    }

    private func importPrivateKeyAction(for cert: ALTX509Certificate) {
        certificateToAddKeyFor = cert
        fileImportMode = .privateKey
        #if !os(tvOS)
        showFileImporter = true
        #else
        guard let topVC = presentingViewController ?? UIApplication.shared.topViewController() else { return }
        TVWebFileTransferManager.shared.startImport(
            acceptedExtensions: ["der", "key", "pem", "p12"],
            title: "Import Private Key (.der/.pem)",
            presentingVC: topVC
        ) { fileURL in
            guard let fileURL = fileURL else { return }
            do {
                let data = try Data(contentsOf: fileURL)
                viewModel.importPrivateKey(data: data, for: cert)
            } catch {
                viewModel.errorMessage = NSLocalizedString("Failed to read private key: ", comment: "") + error.localizedDescription
            }
            certificateToAddKeyFor = nil
        }
        #endif
    }

    private func importCertificatesAction() {
        fileImportMode = .certificate
        #if !os(tvOS)
        showFileImporter = true
        #else
        guard let topVC = presentingViewController ?? UIApplication.shared.topViewController() else { return }
        TVWebFileTransferManager.shared.startImport(
            acceptedExtensions: ["p12", "der", "pem", "cer", "crt"],
            title: "Import Certificates",
            presentingVC: topVC
        ) { fileURL in
            guard let fileURL = fileURL else { return }
            viewModel.startBulkImport(urls: [fileURL])
        }
        #endif
    }
}

private struct LoadingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.2).ignoresSafeArea()
            ProgressView()
                .padding(20)
                #if !os(tvOS)
                .background(Color(.secondarySystemBackground))
                #else
                .background(Color(uiColor: .settingsField))
                #endif
                .cornerRadius(10)
        }
    }
}

private struct CreateCertificateSheetView: View {
    @ObservedObject var viewModel: CertificatesViewModel
    var presentingViewController: UIViewController?
    @Binding var isPresented: Bool
    @State private var machineName = "zLoader - \(UIDevice.current.name)"
    @State private var selectedCertificateType: CertificateType = .development

    private var isPaidWarningVisible: Bool { selectedCertificateType.isPaidOnly && !viewModel.isPaidAccount }
    private var canCreate: Bool {
        AuthManager.shared.isAuthenticated && !machineName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !viewModel.isLoading && !isPaidWarningVisible
    }

    var body: some View {
        NavigationStack {
            List {
                if !AuthManager.shared.isAuthenticated {
                    Text("Sign in to an Apple Account in Settings to create an Apple certificate.", tableName: "CertificatesUI")
                        .foregroundStyle(ZynthecSettingsStyle.secondary).zynthecSettingsRows()
                }
                Section {
                    TextField(text: $machineName) { Text("Name", tableName: "CertificatesUI") }
                    Picker(selection: $selectedCertificateType) {
                        ForEach(viewModel.availableCertificateTypes, id: \.rawValue) { type in
                            Text(verbatim: type.displayName).tag(type)
                        }
                    } label: { Text("Certificate type", tableName: "CertificatesUI") }
                    if viewModel.isLoading { ProgressView() }
                    if let error = viewModel.errorMessage { Text(verbatim: error).foregroundStyle(.red) }
                } footer: {
                    if isPaidWarningVisible {
                        Text("This certificate type requires a paid Apple Developer account.", tableName: "CertificatesUI")
                    } else {
                        Text("The certificate is created in your Apple Developer team. Its private key is saved on this device.", tableName: "CertificatesUI")
                    }
                }.zynthecSettingsRows()
            }
            .zynthecSettingsPage()
            .navigationTitle(Text("Create Apple certificate", tableName: "CertificatesUI"))
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(viewModel.isLoading)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    SwiftUI.Button { isPresented = false } label: { Text("Cancel", tableName: "CertificatesUI") }
                        .disabled(viewModel.isLoading)
                }
                ToolbarItem(placement: .confirmationAction) {
                    SwiftUI.Button {
                        let name = machineName.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard canCreate else { return }
                        Task {
                            if await viewModel.createCertificate(machineName: name, type: selectedCertificateType, presentingViewController: presentingViewController) {
                                isPresented = false
                            }
                        }
                    } label: { Text("Create", tableName: "CertificatesUI") }
                    .disabled(!canCreate)
                    .accessibilityIdentifier("certificates-create-confirm")
                }
            }
        }
    }
}

/// Remote account inventory stays separate from the local signing identities.
struct AccountCertificatesView: View {
    @StateObject private var viewModel = CertificatesViewModel()

    @State private var revokeTarget: ALTX509Certificate?
    @State private var confirmsRevoke = false

    var body: some View {
        List {
            Section {
                if !AuthManager.shared.isAuthenticated {
                    Text("Sign in to an Apple Account in Settings to import from the portal.", tableName: "CertificatesUI")
                        .foregroundStyle(ZynthecSettingsStyle.secondary)
                }
                if viewModel.hasFetchedRemote && viewModel.portalCertificates.isEmpty {
                    Text("There are no certificates on this developer team.")
                        .foregroundStyle(.secondary)
                }
                ForEach(viewModel.portalCertificates, id: \.serialNumber) { cert in
                    NavigationLink {
                        CertificateDetailView(certificate: cert, viewModel: viewModel)
                    } label: { VStack(alignment: .leading, spacing: 8) {
                        Text(cert.name).font(.body)
                        Text(cert.certificateTypeName ?? cert.certificateType ?? cert.serialNumber)
                            .font(.caption).foregroundStyle(.secondary)

                    }.padding(.vertical, 4) }
                    #if !os(tvOS)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        SwiftUI.Button("Revoke", role: .destructive) { revokeTarget = cert; confirmsRevoke = true }
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        SwiftUI.Button("Download") { viewModel.installPortalCertificate(cert) }.tint(.accentColor)
                        SwiftUI.Button("Share") {
                            CertificateExporter.sharePublicCertAsDER(cert, onShare: { viewModel.shareURL = $0 }) { viewModel.errorMessage = $0 }
                        }.tint(.gray)
                    }
                    #endif
                    .contextMenu {
                        SwiftUI.Button("Download") { viewModel.installPortalCertificate(cert) }
                        SwiftUI.Button("Share") {
                            CertificateExporter.sharePublicCertAsDER(cert, onShare: { viewModel.shareURL = $0 }) { viewModel.errorMessage = $0 }
                        }
                        SwiftUI.Button("Revoke", role: .destructive) { revokeTarget = cert; confirmsRevoke = true }
                    }
                }
            } footer: {
                Group {
                    Text("Apple provides the public certificate. A matching local private key is associated automatically. For a certificate from your Mac, import its .p12 containing the private key.")
                }
            }.zynthecSettingsRows()
        }
        .alert("Revoke Certificate", isPresented: $confirmsRevoke) {
            SwiftUI.Button("Revoke", role: .destructive) {
                if let cert = revokeTarget { viewModel.revokeCertificate(cert, keepLocal: false, presentingViewController: nil) }
            }
            SwiftUI.Button("Cancel", role: .cancel) {}
        } message: { Text("Are you sure you want to revoke this certificate? This will permanently delete the certificate on Apple's servers.") }
        .navigationTitle("Certificates from Account")
        .navigationBarTitleDisplayMode(.inline)
        .zynthecSettingsPage()
        .labelStyle(.titleAndIcon)
        .environment(\.settingsEntryIconsVisible, true)
        .task { if AuthManager.shared.isAuthenticated { await viewModel.downloadPortalCertificates() } }
        .refreshable { await viewModel.downloadPortalCertificates() }
        .overlay { if viewModel.isLoading { ProgressView() } }
        .alert("Error", isPresented: $viewModel.showErrorAlert.deferredPresentation()) {
            SwiftUI.Button("OK", role: .cancel) { DispatchQueue.main.async { viewModel.errorMessage = nil } }
        } message: { Text(viewModel.errorMessage ?? "") }
        .alert("Zertifikat importiert", isPresented: $viewModel.showAlert.deferredPresentation()) {
            SwiftUI.Button("OK", role: .cancel) {}
        } message: { Text(viewModel.alertMessage ?? "") }
        .sheet(isPresented: Binding(
            get: { viewModel.shareURL != nil },
            set: { if !$0 { DispatchQueue.main.async { viewModel.shareURL = nil } } }
        )) {
            if let url = viewModel.shareURL { ActivityViewController(activityItems: [url]) }
        }
    }
}
