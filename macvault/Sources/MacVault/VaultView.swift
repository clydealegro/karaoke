import AppKit
import MacVaultCore
import SwiftUI

struct VaultView: View {
    @ObservedObject var model: VaultViewModel

    var body: some View {
        VStack(spacing: 0) {
            if let banner = model.banner {
                BannerView(message: banner) { model.banner = nil }
            }
            switch model.screen {
            case .list:
                ListScreen(model: model)
            case .edit(let login):
                LoginEditor(model: model, original: login)
                    .id(login?.id)
            }
        }
        .frame(width: 360, height: 440)
    }
}

struct BannerView: View {
    let message: String
    let dismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
            Text(message)
                .font(.caption)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: dismiss) {
                Image(systemName: "xmark")
            }
            .buttonStyle(.borderless)
            .help("Dismiss")
        }
        .padding(8)
        .background(Color.yellow.opacity(0.15))
    }
}

struct ListScreen: View {
    @ObservedObject var model: VaultViewModel
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search logins", text: $model.query)
                    .textFieldStyle(.plain)
                    .focused($searchFocused)
                    .onSubmit {
                        Task { await model.copyTopMatchPassword() }
                    }
                Button {
                    model.screen = .edit(nil)
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
                .help("New login")
            }
            .padding(10)

            Divider()

            if model.filteredLogins.isEmpty {
                Spacer()
                Text(model.logins.isEmpty ? "No logins yet.\nClick + to add one." : "No matches")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                List(model.filteredLogins) { login in
                    LoginRow(login: login, model: model)
                }
                .listStyle(.plain)
            }

            Divider()

            HStack {
                Text(model.flash ?? "⌥⌘P opens MacVault · Return copies top password")
                    .font(.caption)
                    .foregroundStyle(model.flash == nil ? Color.secondary : Color.accentColor)
                    .lineLimit(1)
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
                    .buttonStyle(.borderless)
                    .font(.caption)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
        }
        .onAppear { searchFocused = true }
        .onChange(of: model.focusToken) { _ in searchFocused = true }
    }
}
