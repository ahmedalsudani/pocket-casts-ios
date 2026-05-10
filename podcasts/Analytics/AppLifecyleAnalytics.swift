import Foundation

/// Telemetry has been removed. The class is preserved (instead of deleted)
/// because AppDelegate still needs `AppInstallState` and
/// `checkApplicationInstalledOrUpgraded()` to decide whether to suppress
/// tooltips on a fresh install. Everything else is a no-op.
class AppLifecycleAnalytics {
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard, analytics: Analytics = Analytics.shared) {
        self.userDefaults = userDefaults
    }
}

// MARK: - App Opened/Closed

extension AppLifecycleAnalytics {
    func didBecomeActive() {}

    func didEnterBackground() {}
}

// MARK: - App Install/Updates

extension AppLifecycleAnalytics {
    enum AppInstallState {
        case installed
        case updated
        case sameVersion
    }

    /// Returns whether the current launch is a fresh install, an upgrade
    /// from a previous version, or the same version as last launch. No
    /// analytics event is emitted; the caller (AppDelegate) uses the result
    /// to decide whether to show fresh-install tooltips.
    func checkApplicationInstalledOrUpgraded() -> AppInstallState? {
        guard UIApplication.shared.isProtectedDataAvailable else { return nil }

        let currentVersion = Settings.appVersion()

        defer {
            userDefaults.set(currentVersion, forKey: Constants.UserDefaults.lastRunVersion)
            userDefaults.synchronize()
        }

        guard let lastRunVersion = userDefaults.string(forKey: Constants.UserDefaults.lastRunVersion) else {
            return .installed
        }

        return lastRunVersion == currentVersion ? .sameVersion : .updated
    }
}
