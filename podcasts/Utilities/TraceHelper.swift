import Foundation
import PocketCastsUtils

/// FirebasePerformance has been removed. The handler is preserved so
/// `TraceManager.shared.setup(handler:)` compiles, but tracing is a no-op.
class TraceHelper: TraceHandlingProtocol {
    func beginTracing(eventName: String) -> AnyObject? {
        nil
    }

    func endTracing(trace: AnyObject) {}
}
