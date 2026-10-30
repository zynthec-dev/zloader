import SwiftUI
import UniformTypeIdentifiers

struct CertificateRequestDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.data] }
    let data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

struct CertificateRequestView: View {
    @Environment(\.dismiss) private var dismiss
    var onCreated: () -> Void
    @State private var name = ""
    @State private var email = ""
    @State private var organization = ""
    @State private var isCreating = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField(text: $name) { Text("Name", tableName: "CertificatesUI") }
                        .accessibilityIdentifier("certificate-request-name")
                    TextField(text: $email) { Text("Email (optional)", tableName: "CertificatesUI") }
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                    TextField(text: $organization) { Text("Organization (optional)", tableName: "CertificatesUI") }
                } footer: {
                    Text("Create a signing request (CSR), then export it to your certificate authority. The matching private key stays on this device.", tableName: "CertificatesUI")
                        .foregroundStyle(ZynthecSettingsStyle.secondary)
                }.zynthecSettingsRows(isInput: true)
                if isCreating { ProgressView().zynthecSettingsRows() }
            }
            .zynthecSettingsPage()
            .navigationTitle(Text("Request", tableName: "CertificatesUI"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    SwiftUI.Button { dismiss() } label: { Text("Cancel", tableName: "CertificatesUI") }
                        .disabled(isCreating)
                }
                ToolbarItem(placement: .confirmationAction) {
                    SwiftUI.Button { create() } label: { Text("Create", tableName: "CertificatesUI") }
                        .disabled(isCreating || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityIdentifier("certificate-request-create")
                }
            }
            .interactiveDismissDisabled(isCreating)
            .alert(Text("Certificate request", tableName: "CertificatesUI"), isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                SwiftUI.Button("OK", role: .cancel) { errorMessage = nil }
            } message: { Text(verbatim: errorMessage ?? "") }
        }
    }

    private func create() {
        let commonName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let mail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let company = organization.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !commonName.isEmpty, !isCreating else { return }
        isCreating = true
        Task {
            defer { isCreating = false }
            do {
                _ = try await Task.detached {
                    try LocalKeyMaterialStore.createRequest(name: commonName, email: mail, organization: company)
                }.value
                onCreated()
                dismiss()
            } catch { errorMessage = error.localizedDescription }
        }
    }
}
