import PocketCastsUtils
import WatchKit

class ExtensionDelegate: NSObject, WKApplicationDelegate {
    private var haveAttemptedStateRestore = false

    func applicationDidFinishLaunching() {
        SessionManager.shared.setup()
        WatchSyncManager.shared.setup()
        restorePreviousStateIfRequired()
    }

    func handleUserActivity(_ userInfo: [AnyHashable: Any]?) {
        restorePreviousStateIfRequired()
    }

    // indicates that the app was auto launched by watchOS because audio from the phone started playing
    func handleRemoteNowPlayingActivity() {
        haveAttemptedStateRestore = true
        NavigationManager.shared.navigateToNowPlaying()
    }

    func handle(_ backgroundTasks: Set<WKRefreshBackgroundTask>) {
        // Sent when the system needs to launch the application in the background to process tasks. Tasks arrive in a set, so loop through and process each one.
        FileLog.shared.addMessage("Watch Extension Delegate start handle background task")
        for task in backgroundTasks {
            switch task {
            case let snapshotTask as WKSnapshotRefreshBackgroundTask:
                snapshotTask.setTaskCompleted(restoredDefaultState: true, estimatedSnapshotExpiration: Date.distantFuture, userInfo: nil)
            case let connectivityTask as WKWatchConnectivityRefreshBackgroundTask:
                connectivityTask.setTaskCompletedWithSnapshot(true)
            case let urlSessionTask as WKURLSessionRefreshBackgroundTask:
                urlSessionTask.setTaskCompletedWithSnapshot(true)
            default:
                task.setTaskCompletedWithSnapshot(false)
            }
        }
    }

    // MARK: - State restoration

    private func restorePreviousStateIfRequired() {
        guard let lastPage = UserDefaults.standard.string(forKey: WatchConstants.UserDefaults.lastPage) else { return }

        let context = UserDefaults.standard.object(forKey: WatchConstants.UserDefaults.lastContext)
        if !haveAttemptedStateRestore {
            haveAttemptedStateRestore = true
            NavigationManager.shared.navigateToRestorable(name: lastPage, context: context)
        }
    }
}
