import Foundation

public protocol Pasteboard: AnyObject {
    var changeCount: Int { get }
    /// Replaces the contents and returns the new change count. `concealed`
    /// marks the item so clipboard-history apps skip it.
    func write(_ string: String, concealed: Bool) -> Int
    func clear()
}

public protocol Scheduler {
    func schedule(after seconds: TimeInterval, _ action: @escaping () -> Void)
}

public struct DispatchScheduler: Scheduler {
    public init() {}

    public func schedule(after seconds: TimeInterval, _ action: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: action)
    }
}

public final class ClipboardGuard {
    public static let defaultClearDelay: TimeInterval = 30

    private let pasteboard: Pasteboard
    private let scheduler: Scheduler

    public init(pasteboard: Pasteboard, scheduler: Scheduler) {
        self.pasteboard = pasteboard
        self.scheduler = scheduler
    }

    /// Copies `string`. With a delay, the item is concealed and cleared after
    /// the delay unless something else has been copied in the meantime.
    public func copy(_ string: String, clearAfter delay: TimeInterval?) {
        let pasteboard = self.pasteboard
        let changeCount = pasteboard.write(string, concealed: delay != nil)
        guard let delay else { return }
        scheduler.schedule(after: delay) {
            if pasteboard.changeCount == changeCount {
                pasteboard.clear()
            }
        }
    }
}
