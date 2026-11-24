#if canImport(Security)
import Security
import XCTest
@testable import MacVaultCore

final class KeychainLoginStoreTests: XCTestCase {
    private var store: KeychainLoginStore!

    override func setUpWithError() throws {
        store = KeychainLoginStore(service: "MacVaultTests-\(UUID().uuidString)")
    }

    override func tearDownWithError() throws {
        for login in (try? store.list()) ?? [] {
            try? store.delete(id: login.id)
        }
        store = nil
    }

    func testSaveThenListAndReadPassword() throws {
        try LoginStoreContract.saveThenListAndReadPassword(store)
    }
    func testUpdateWithoutPasswordKeepsPassword() throws {
        try LoginStoreContract.updateWithoutPasswordKeepsPassword(store)
    }
    func testUpdateWithPasswordReplacesIt() throws {
        try LoginStoreContract.updateWithPasswordReplacesIt(store)
    }
    func testNewLoginWithoutPasswordIsRejected() {
        LoginStoreContract.newLoginWithoutPasswordIsRejected(store)
    }
    func testEmptyTitleIsRejected() {
        LoginStoreContract.emptyTitleIsRejected(store)
    }
    func testDeleteRemovesLogin() throws {
        try LoginStoreContract.deleteRemovesLogin(store)
    }
    func testListIsSortedByTitle() throws {
        try LoginStoreContract.listIsSortedByTitle(store)
    }

    func testUnicodePasswordRoundTrips() throws {
        let login = Login(title: "Café")
        try store.save(login, password: "pässwörd🔑")
        XCTAssertEqual(try store.password(for: login.id), "pässwörd🔑")
    }

    func testStoresAreIsolatedByService() throws {
        try store.save(Login(title: "Mine"), password: "pw")
        let other = KeychainLoginStore(service: "MacVaultTests-\(UUID().uuidString)")
        XCTAssertTrue(try other.list().isEmpty)
    }

    func testItemWithUnreadableMetadataIsStillListed() throws {
        let id = UUID()
        let add: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: store.service,
            kSecAttrAccount as String: id.uuidString,
            kSecAttrGeneric as String: Data("not json".utf8),
            kSecValueData as String: Data("pw".utf8),
        ]
        XCTAssertEqual(SecItemAdd(add as CFDictionary, nil), errSecSuccess)
        let listed = try store.list()
        XCTAssertEqual(listed.map(\.id), [id])
        XCTAssertEqual(listed.first?.title, id.uuidString)
    }
}
#endif
