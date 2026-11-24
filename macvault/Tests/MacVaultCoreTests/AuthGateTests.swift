import XCTest
@testable import MacVaultCore

@MainActor
final class FakeAuthenticator: Authenticator {
    var result = true
    private(set) var reasons: [String] = []

    func authenticate(reason: String) async -> Bool {
        reasons.append(reason)
        return result
    }
}

final class TestClock {
    var now = Date(timeIntervalSince1970: 1_000_000)
}

final class AuthGateTests: XCTestCase {
    @MainActor
    private func makeGate() -> (AuthGate, FakeAuthenticator, TestClock) {
        let authenticator = FakeAuthenticator()
        let clock = TestClock()
        let gate = AuthGate(authenticator: authenticator, gracePeriod: 300, now: { clock.now })
        return (gate, authenticator, clock)
    }

    @MainActor
    func testFirstUsePromptsAndSuccessIsRemembered() async {
        let (gate, authenticator, clock) = makeGate()
        let first = await gate.ensureAuthenticated(reason: "copy")
        XCTAssertTrue(first)
        clock.now += 299
        let second = await gate.ensureAuthenticated(reason: "copy again")
        XCTAssertTrue(second)
        XCTAssertEqual(authenticator.reasons, ["copy"])
    }

    @MainActor
    func testPromptsAgainAfterGracePeriod() async {
        let (gate, authenticator, clock) = makeGate()
        _ = await gate.ensureAuthenticated(reason: "a")
        clock.now += 301
        XCTAssertTrue(gate.needsAuthentication())
        _ = await gate.ensureAuthenticated(reason: "b")
        XCTAssertEqual(authenticator.reasons, ["a", "b"])
    }

    @MainActor
    func testFailureIsNotRemembered() async {
        let (gate, authenticator, _) = makeGate()
        authenticator.result = false
        let allowed = await gate.ensureAuthenticated(reason: "a")
        XCTAssertFalse(allowed)
        XCTAssertTrue(gate.needsAuthentication())
    }

    @MainActor
    func testLockForcesPrompt() async {
        let (gate, authenticator, _) = makeGate()
        _ = await gate.ensureAuthenticated(reason: "a")
        gate.lock()
        _ = await gate.ensureAuthenticated(reason: "b")
        XCTAssertEqual(authenticator.reasons, ["a", "b"])
    }
}
