import Foundation
import UIKit

/// Whether this launch is the app's first, its first since an update, or neither
enum AppInstallState {
    case installed
    case updated
    case sameVersion

    /// Compares the version that ran last against this one, then records this one for next time.
    ///
    /// Returns nil when protected data isn't available yet, which happens when the app is launched in the
    /// background on a locked device, because the last run version can't be read then.
    static func check(userDefaults: UserDefaults = .standard) -> AppInstallState? {
        guard UIApplication.shared.isProtectedDataAvailable else { return nil }

        let currentVersion = Settings.appVersion()

        defer {
            userDefaults.set(currentVersion, forKey: Constants.UserDefaults.lastRunVersion)
        }

        guard let lastRunVersion = lastRunVersion(in: userDefaults) else {
            return .installed
        }

        return lastRunVersion == currentVersion ? .sameVersion : .updated
    }

    private static func lastRunVersion(in userDefaults: UserDefaults) -> String? {
        if let lastRunVersion = userDefaults.string(forKey: Constants.UserDefaults.lastRunVersion) {
            return lastRunVersion
        }

        // Versions before 7.21 didn't record the last run version, so guess it from the keys they set when
        // they first ran (see AppDelegate+Defaults). Ordered from newest to oldest.
        let versionMap: KeyValuePairs = [
            "v7_20_1_Ghost_Fix": "7.20.1",
            "FoldersInitialRun": "7.20.0",
            "v7_19_1Run": "7.19.1",
            "v7_16Run": "7.16.0",
            "v7_15Run": "7.15.0",
            "v7_12Run": "7.12.0",
            "v7_11Run": "7.11.0",
            "v7_3Run": "7.3.0"
        ]

        return versionMap.first { key, _ in userDefaults.bool(forKey: key) }?.value
    }
}
