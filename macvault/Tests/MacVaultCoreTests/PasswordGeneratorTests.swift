import XCTest
@testable import MacVaultCore

/// Deterministic SplitMix64 so tests are repeatable.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

final class PasswordGeneratorTests: XCTestCase {
    private func generate(_ options: PasswordOptions, seed: UInt64) -> String {
        var rng = SeededGenerator(seed: seed)
        return PasswordGenerator.generate(options, using: &rng)
    }

    func testDefaultHasLength20AndEveryCharacterClass() {
        for seed: UInt64 in 0..<200 {
            let password = generate(.default, seed: seed)
            XCTAssertEqual(password.count, 20)
            XCTAssertTrue(password.contains { PasswordGenerator.lowercase.contains($0) })
            XCTAssertTrue(password.contains { PasswordGenerator.uppercase.contains($0) })
            XCTAssertTrue(password.contains { PasswordGenerator.digits.contains($0) })
            XCTAssertTrue(password.contains { PasswordGenerator.symbols.contains($0) })
        }
    }

    func testLengthIsClampedTo8Through64() {
        XCTAssertEqual(generate(PasswordOptions(length: 3), seed: 1).count, 8)
        XCTAssertEqual(generate(PasswordOptions(length: 500), seed: 1).count, 64)
    }

    func testDisabledClassesAreExcluded() {
        let options = PasswordOptions(length: 64, includeDigits: false, includeSymbols: false)
        for seed: UInt64 in 0..<50 {
            let password = generate(options, seed: seed)
            XCTAssertFalse(password.contains { PasswordGenerator.digits.contains($0) })
            XCTAssertFalse(password.contains { PasswordGenerator.symbols.contains($0) })
        }
    }

    func testLookAlikeCharactersNeverAppear() {
        for seed: UInt64 in 0..<200 {
            let password = generate(PasswordOptions(length: 64), seed: seed)
            XCTAssertFalse(password.contains { "0O1lI".contains($0) }, password)
        }
    }

    func testSameSeedSameResult() {
        XCTAssertEqual(generate(.default, seed: 42), generate(.default, seed: 42))
        XCTAssertNotEqual(generate(.default, seed: 42), generate(.default, seed: 43))
    }

    func testSystemRandomVersionProducesDifferentPasswords() {
        let first = PasswordGenerator.generate()
        let second = PasswordGenerator.generate()
        XCTAssertEqual(first.count, 20)
        XCTAssertNotEqual(first, second)
    }
}
