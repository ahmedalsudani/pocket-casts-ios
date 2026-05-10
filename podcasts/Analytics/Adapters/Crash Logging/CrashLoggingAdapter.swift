import Foundation

/// Automattic remote crash logging has been removed. The adapter is kept
/// only because some call sites still reference `CrashLoggingAdapter.sharedManager`
/// (e.g. for graceful nil-checks) — every member is a no-op now.
class CrashLoggingAdapter: AnalyticsAdapter {
    static var sharedManager: CrashLoggingAdapter?

    init() {
        Self.sharedManager = self
    }

    func track(name: String, properties: [AnyHashable: Any]?) {}
}
