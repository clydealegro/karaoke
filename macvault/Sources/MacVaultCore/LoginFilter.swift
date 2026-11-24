import Foundation

public enum LoginFilter {
    /// Logins matching `query` in title, username or website (case- and
    /// accent-insensitive). Title-prefix matches come first, then the rest;
    /// each group is sorted by title. An empty query returns everything.
    public static func filter(_ logins: [Login], query: String) -> [Login] {
        let sorted = logins.sortedByTitle()
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return sorted }

        let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
        func contains(_ haystack: String) -> Bool {
            haystack.range(of: needle, options: options) != nil
        }

        let prefixMatches = sorted.filter {
            $0.title.range(of: needle, options: options.union(.anchored)) != nil
        }
        let prefixIDs = Set(prefixMatches.map(\.id))
        let otherMatches = sorted.filter { login in
            !prefixIDs.contains(login.id)
                && (contains(login.title) || contains(login.username) || contains(login.website))
        }
        return prefixMatches + otherMatches
    }
}
