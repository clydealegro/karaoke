import Foundation

public struct PasswordOptions: Equatable {
    public static let lengthRange = 8...64
    public static let `default` = PasswordOptions()

    public var length: Int
    public var includeDigits: Bool
    public var includeSymbols: Bool

    public init(length: Int = 20, includeDigits: Bool = true, includeSymbols: Bool = true) {
        self.length = length
        self.includeDigits = includeDigits
        self.includeSymbols = includeSymbols
    }
}

public enum PasswordGenerator {
    // Look-alikes 0 O 1 l I are left out so passwords are easy to read and type.
    public static let lowercase = Array("abcdefghijkmnopqrstuvwxyz")
    public static let uppercase = Array("ABCDEFGHJKLMNPQRSTUVWXYZ")
    public static let digits = Array("23456789")
    public static let symbols = Array("!@#$%^&*-_=+?")

    /// Uses the system CSPRNG (`SystemRandomNumberGenerator`).
    public static func generate(_ options: PasswordOptions = .default) -> String {
        var rng = SystemRandomNumberGenerator()
        return generate(options, using: &rng)
    }

    /// Always contains at least one character from every enabled class.
    public static func generate<R: RandomNumberGenerator>(
        _ options: PasswordOptions,
        using rng: inout R
    ) -> String {
        let length = min(max(options.length, PasswordOptions.lengthRange.lowerBound),
                         PasswordOptions.lengthRange.upperBound)
        var classes = [lowercase, uppercase]
        if options.includeDigits { classes.append(digits) }
        if options.includeSymbols { classes.append(symbols) }

        var characters = classes.map { $0.randomElement(using: &rng)! }
        let pool = classes.flatMap { $0 }
        while characters.count < length {
            characters.append(pool.randomElement(using: &rng)!)
        }
        characters.shuffle(using: &rng)
        return String(characters)
    }
}
