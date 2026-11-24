import XCTest
@testable import MacVaultCore

/// Behaviour every LoginStore must have. Each concrete test class calls these.
enum LoginStoreContract {
    static func saveThenListAndReadPassword(_ store: LoginStore) throws {
        let login = Login(title: "GitHub", username: "octo", website: "https://github.com")
        try store.save(login, password: "s3cret!")
        XCTAssertEqual(try store.list().map(\.title), ["GitHub"])
        XCTAssertEqual(try store.list().first?.username, "octo")
        XCTAssertEqual(try store.password(for: login.id), "s3cret!")
    }

    static func updateWithoutPasswordKeepsPassword(_ store: LoginStore) throws {
        var login = Login(title: "Mail", username: "me")
        try store.save(login, password: "first")
        login.title = "Mail (work)"
        try store.save(login, password: nil)
        XCTAssertEqual(try store.list().map(\.title), ["Mail (work)"])
        XCTAssertEqual(try store.password(for: login.id), "first")
    }

    static func updateWithPasswordReplacesIt(_ store: LoginStore) throws {
        let login = Login(title: "Bank")
        try store.save(login, password: "old")
        try store.save(login, password: "new")
        XCTAssertEqual(try store.password(for: login.id), "new")
        XCTAssertEqual(try store.list().count, 1)
    }

    static func newLoginWithoutPasswordIsRejected(_ store: LoginStore) {
        XCTAssertThrowsError(try store.save(Login(title: "X"), password: nil)) { error in
            XCTAssertEqual(error as? LoginStoreError, .invalidInput("Password can't be empty."))
        }
        XCTAssertThrowsError(try store.save(Login(title: "X"), password: ""))
    }

    static func emptyTitleIsRejected(_ store: LoginStore) {
        XCTAssertThrowsError(try store.save(Login(title: "  "), password: "pw")) { error in
            XCTAssertEqual(error as? LoginStoreError, .invalidInput("Name can't be empty."))
        }
    }

    static func deleteRemovesLogin(_ store: LoginStore) throws {
        let login = Login(title: "Old")
        try store.save(login, password: "pw")
        try store.delete(id: login.id)
        XCTAssertTrue(try store.list().isEmpty)
        XCTAssertThrowsError(try store.password(for: login.id)) { error in
            XCTAssertEqual(error as? LoginStoreError, .notFound)
        }
        XCTAssertThrowsError(try store.delete(id: login.id)) { error in
            XCTAssertEqual(error as? LoginStoreError, .notFound)
        }
    }

    static func listIsSortedByTitle(_ store: LoginStore) throws {
        try store.save(Login(title: "zoom"), password: "1")
        try store.save(Login(title: "Apple"), password: "2")
        XCTAssertEqual(try store.list().map(\.title), ["Apple", "zoom"])
    }
}
