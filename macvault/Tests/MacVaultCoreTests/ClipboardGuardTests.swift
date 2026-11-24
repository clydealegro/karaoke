import XCTest
@testable import MacVaultCore

final class FakePasteboard: Pasteboard {
    private(set) var changeCount = 0
    private(set) var contents: String?
    private(set) var lastWriteConcealed = false

    func write(_ string: String, concealed: Bool) -> Int {
        contents = string
        lastWriteConcealed = concealed
        changeCount += 1
        return changeCount
    }

    func clear() {
        contents = nil
        changeCount += 1
    }

    /// Simulates the user copying something in another app.
    func externalCopy(_ string: String) {
        contents = string
        changeCount += 1
    }
}

final class ManualScheduler: Scheduler {
    private(set) var delays: [TimeInterval] = []
    private var actions: [() -> Void] = []

    func schedule(after seconds: TimeInterval, _ action: @escaping () -> Void) {
        delays.append(seconds)
        actions.append(action)
    }

    func runAll() {
        let pending = actions
        actions = []
        pending.forEach { $0() }
    }
}

final class ClipboardGuardTests: XCTestCase {
    let pasteboard = FakePasteboard()
    let scheduler = ManualScheduler()
    lazy var guardian = ClipboardGuard(pasteboard: pasteboard, scheduler: scheduler)

    func testCopyWithoutDelayIsPlainAndNeverCleared() {
        guardian.copy("octo", clearAfter: nil)
        XCTAssertEqual(pasteboard.contents, "octo")
        XCTAssertFalse(pasteboard.lastWriteConcealed)
        XCTAssertTrue(scheduler.delays.isEmpty)
    }

    func testCopyWithDelayIsConcealedAndClearedLater() {
        guardian.copy("s3cret", clearAfter: 30)
        XCTAssertEqual(pasteboard.contents, "s3cret")
        XCTAssertTrue(pasteboard.lastWriteConcealed)
        XCTAssertEqual(scheduler.delays, [30])
        scheduler.runAll()
        XCTAssertNil(pasteboard.contents)
    }

    func testDoesNotClearIfUserCopiedSomethingElse() {
        guardian.copy("s3cret", clearAfter: 30)
        pasteboard.externalCopy("my notes")
        scheduler.runAll()
        XCTAssertEqual(pasteboard.contents, "my notes")
    }

    func testSecondCopyIsNotClearedByFirstTimer() {
        guardian.copy("first", clearAfter: 30)
        guardian.copy("second", clearAfter: nil)
        scheduler.runAll()
        XCTAssertEqual(pasteboard.contents, "second")
    }
}
