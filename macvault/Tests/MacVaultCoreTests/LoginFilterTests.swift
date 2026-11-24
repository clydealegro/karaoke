import XCTest
@testable import MacVaultCore

final class LoginFilterTests: XCTestCase {
    let github = Login(title: "GitHub", username: "octo")
    let server = Login(title: "My Git Server", username: "admin")
    let bank = Login(title: "Bank", username: "gitfan")
    let shop = Login(title: "Shop", username: "buyer", website: "https://shop.example.com")

    var all: [Login] { [shop, server, bank, github] }

    func testEmptyQueryReturnsAllSortedByTitle() {
        XCTAssertEqual(LoginFilter.filter(all, query: "").map(\.title),
                       ["Bank", "GitHub", "My Git Server", "Shop"])
    }

    func testWhitespaceQueryCountsAsEmpty() {
        XCTAssertEqual(LoginFilter.filter(all, query: "   ").count, 4)
    }

    func testTitlePrefixMatchesComeFirst() {
        XCTAssertEqual(LoginFilter.filter(all, query: "git").map(\.title),
                       ["GitHub", "Bank", "My Git Server"])
    }

    func testMatchesWebsiteCaseInsensitively() {
        XCTAssertEqual(LoginFilter.filter(all, query: "EXAMPLE.com").map(\.title), ["Shop"])
    }

    func testNoMatchReturnsEmpty() {
        XCTAssertTrue(LoginFilter.filter(all, query: "zzz").isEmpty)
    }
}
