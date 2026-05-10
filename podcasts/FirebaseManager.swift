import PocketCastsUtils

/// Firebase Remote Config has been removed. The shim keeps the public
/// surface so existing callers compile but never reaches the network.
struct FirebaseManager {
    /// Mirrors the public type alias `RemoteConfigFetchStatus` previously
    /// exposed by FirebaseRemoteConfig. With remote config gone we only
    /// ever report `.success` (cached defaults are local-only).
    enum RemoteConfigFetchStatus {
        case success
        case failure
    }

    static func refreshRemoteConfig(expirationDuration: TimeInterval = 2.hour, completion: ((RemoteConfigFetchStatus) -> Void)? = nil) {
        completion?(.success)
    }
}
