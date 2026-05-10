import Foundation
import PocketCastsDataModel
import PocketCastsUtils

#if os(watchOS)
    import WatchKit
#endif

/// Background-sync used to drive a background URLSession with three
/// downloads: refresh, up-next sync, and incremental sync. With the
/// account / sync subsystem gone, "background sync" is just a regular
/// local refresh. The class is kept as a thin shim so the watch app's
/// `processBackgroundTaskCallback` and `performBackgroundRefresh` call
/// sites compile.
public class BackgroundSyncManager: NSObject {
    public static let sessionIdPrefix = "SyncBgSession"

    public static let shared = BackgroundSyncManager()

    #if os(watchOS)
    public func processBackgroundTaskCallback(task: WKURLSessionRefreshBackgroundTask, identifier: String) {
        task.setTaskCompletedWithSnapshot(false)
    }
    #endif

    public func performBackgroundRefresh(subscribedPodcasts: [Podcast]) {
        FileLog.shared.addMessage("BackgroundSyncManager.performBackgroundRefresh — delegating to local refresh")
        RefreshManager.shared.refreshPodcasts(forceEvenIfRefreshedRecently: true)
    }

    /// Value returned by `URLResponse.expectedContentLength` when the length is unknown.
    static let unknownContentLength: Int64 = -1

    /// Returns `true` if the download is complete (received bytes match expected),
    /// or if the expected length is unknown (Content-Length not set / chunked transfer).
    static func isDownloadComplete(receivedBytes: Int, expectedContentLength: Int64) -> Bool {
        guard expectedContentLength != unknownContentLength else {
            return true
        }
        return Int64(receivedBytes) == expectedContentLength
    }
}
