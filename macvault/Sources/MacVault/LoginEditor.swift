import MacVaultCore
import SwiftUI

struct LoginEditor: View {
    @ObservedObject var model: VaultViewModel
    let original: Login?

    @State private var title: String
    @State private var username: String
    @State private var website: String
    /// Empty while editing means "keep the saved password".
    @State private var password = ""
    @State private var showPassword: Bool
    @State private var options = PasswordOptions.default
    @State private var confirmDelete = false

    init(model: VaultViewModel, original: Login?) {
        _model = ObservedObject(wrappedValue: model)
        self.original = original
        _title = State(initialValue: original?.title ?? "")
        _username = State(initialValue: original?.username ?? "")
        _website = State(initialValue: original?.website ?? "")
        _showPassword = State(initialValue: original == nil)
    }

    private var isNew: Bool { original == nil }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && (!isNew || !password.isEmpty)
    }

    private var lengthBinding: Binding<Double> {
        Binding(
            get: { Double(options.length) },
            set: { options.length = Int($0) }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Cancel") { model.screen = .list }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Text(isNew ? "New Login" : "Edit Login").font(.headline)
                Spacer()
                Button("Save", action: save)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canSave)
            }
            .padding(10)

            Divider()

            Form {
                Section {
                    TextField("Name", text: $title)
                    TextField("Username", text: $username)
                    HStack {
                        if showPassword {
                            TextField("Password", text: $password,
                                      prompt: Text(isNew ? "" : "Unchanged"))
                                .font(.body.monospaced())
                        } else {
                            SecureField("Password", text: $password,
                                        prompt: Text(isNew ? "" : "Unchanged"))
                        }
                        Button {
                            Task { await toggleReveal() }
                        } label: {
                            Image(systemName: showPassword ? "eye.slash" : "eye")
                        }
                        .buttonStyle(.borderless)
                        .help(showPassword ? "Hide password" : "Show password")
                    }
                    TextField("Website", text: $website)
                }

                Section("Generator") {
                    HStack {
                        Slider(value: lengthBinding,
                               in: Double(PasswordOptions.lengthRange.lowerBound)...Double(PasswordOptions.lengthRange.upperBound),
                               step: 1)
                        Text("\(options.length)")
                            .monospacedDigit()
                            .frame(width: 24, alignment: .trailing)
                    }
                    HStack {
                        Toggle("Digits", isOn: $options.includeDigits)
                        Toggle("Symbols", isOn: $options.includeSymbols)
                        Spacer()
                        Button("Generate") {
                            password = PasswordGenerator.generate(options)
                            showPassword = true
                        }
                    }
                }

                if let original {
                    Section {
                        Button("Delete Login", role: .destructive) { confirmDelete = true }
                            .alert("Delete “\(original.title)”?", isPresented: $confirmDelete) {
                                Button("Delete", role: .destructive) { model.delete(original) }
                                Button("Cancel", role: .cancel) {}
                            } message: {
                                Text("It will be removed from your Keychain.")
                            }
                    }
                }
            }
            .formStyle(.grouped)
        }
    }

    private func toggleReveal() async {
        if showPassword {
            showPassword = false
            return
        }
        // New logins, or a password the user already typed: nothing secret to fetch.
        guard let original, password.isEmpty else {
            showPassword = true
            return
        }
        if let saved = await model.revealPassword(for: original) {
            password = saved
            showPassword = true
        }
    }

    private func save() {
        guard canSave else { return }
        var login = original ?? Login(title: "")
        login.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        login.username = username.trimmingCharacters(in: .whitespacesAndNewlines)
        login.website = website.trimmingCharacters(in: .whitespacesAndNewlines)
        login.updatedAt = Date()
        model.save(login, password: password.isEmpty ? nil : password)
    }
}
