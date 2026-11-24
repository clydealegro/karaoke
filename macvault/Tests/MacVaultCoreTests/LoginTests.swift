import XCTest
@testable import MacVaultCore

final class LoginTests: XCTestCase {
    func testDefaultsAreEmpty() {
        let login = Login(title: "GitHub")
        XCTAssertEqual(login.username, "")
        XCTAssertEqual(login.website, "")
    }

    func testSortedByTitleIsCaseInsensitive() {
        let logins = [Login(title: "zoom"), Login(title: "Apple"), Login(title: "bank")]
        XCTAssertEqual(logins.sortedByTitle().map(\.title), ["Apple", "bank", "zoom"])
    }

    func testCodableRoundTrip() throws {
        let login = Login(title: "Mail", username: "me", website: "https://mail.example.com",
                          updatedAt: Date(timeIntervalSince1970: 1_700_000_000))
        let data = try JSONEncoder().encode(login)
        XCTAssertEqual(try JSONDecoder().decode(Login.self, from: data), login)
    }
}
