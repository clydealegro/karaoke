import MacVaultCore
import SwiftUI

struct LoginRow: View {
    let login: Login
    @ObservedObject var model: VaultViewModel

    var body: some View {
        HStack(spacing: 10) {
            Text(String(login.title.prefix(1)).uppercased())
                .font(.headline)
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Color.accentColor))

            VStack(alignment: .leading, spacing: 2) {
                Text(login.title)
                    .fontWeight(.medium)
                    .lineLimit(1)
                Text(login.username.isEmpty ? login.website : login.username)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button {
                model.copyUsername(login)
            } label: {
                Image(systemName: "person.crop.circle")
            }
            .help("Copy username")
            .disabled(login.username.isEmpty)

            Button {
                Task { await model.copyPassword(login) }
            } label: {
                Image(systemName: "key.fill")
            }
            .help("Copy password")

            Button {
                model.screen = .edit(login)
            } label: {
                Image(systemName: "pencil")
            }
            .help("Edit")
        }
        .buttonStyle(.borderless)
        .padding(.vertical, 4)
    }
}
