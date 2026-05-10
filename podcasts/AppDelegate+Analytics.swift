import PocketCastsServer
import PocketCastsUtils
import PocketCastsDataModel

extension AppDelegate {
    /// Telemetry has been removed. The hooks remain so the AppDelegate
    /// flow compiles, but every method is a no-op — no Tracks events,
    /// no crash-logging adapter, no live analytics stream, no
    /// notifications-coordinator subscription, no protected-data
    /// observer.
    func setupAnalytics() {}

    func logActiveDownloadTasks() {}

    func logStaleDownloads() {}

    func addAnalyticsObservers() {}

    /// User-id retrieval was an account-recovery path; with the account
    /// subsystem gone there's nothing to retrieve.
    func retrieveUserIdIfNeeded() {}
}
