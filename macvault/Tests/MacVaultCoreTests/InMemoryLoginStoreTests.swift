import XCTest
@testable import MacVaultCore

final class InMemoryLoginStoreTests: XCTestCase {
    func testSaveThenListAndReadPassword() throws {
        try LoginStoreContract.saveThenListAndReadPassword(InMemoryLoginStore())
    }
    func testUpdateWithoutPasswordKeepsPassword() throws {
        try LoginStoreContract.updateWithoutPasswordKeepsPassword(InMemoryLoginStore())
    }
    func testUpdateWithPasswordReplacesIt() throws {
        try LoginStoreContract.updateWithPasswordReplacesIt(InMemoryLoginStore())
    }
    func testNewLoginWithoutPasswordIsRejected() {
        LoginStoreContract.newLoginWithoutPasswordIsRejected(InMemoryLoginStore())
    }
    func testEmptyTitleIsRejected() {
        LoginStoreContract.emptyTitleIsRejected(InMemoryLoginStore())
    }
    func testDeleteRemovesLogin() throws {
        try LoginStoreContract.deleteRemovesLogin(InMemoryLoginStore())
    }
    func testListIsSortedByTitle() throws {
        try LoginStoreContract.listIsSortedByTitle(InMemoryLoginStore())
    }
}
