import Foundation
import PocketCastsDataModel
import PocketCastsServer
import PocketCastsUtils

class ServerSyncManager: ServerSyncDelegate {
    static let shared = ServerSyncManager()
    private static let networkDataUsageRetentionPeriod: TimeInterval = 30.days
    private static let networkDataUsageCleanupInterval: TimeInterval = 24.hours

    // MARK: - Podcast functions

    func podcastAdded(podcastUuid: String) {
        NotificationCenter.postOnMainThread(notification: Constants.Notifications.podcastAdded, object: podcastUuid)
    }

    func checkForUnusedPodcasts() {
        Task {
            await PodcastManager.shared.checkForUnusedPodcasts()
        }
    }

    func applyAutoArchivingToAllPodcasts() {
        PodcastManager.shared.applyAutoArchivingToAllPodcasts()
    }

    // MARK: - Episode functions

    func cleanupAllUnusedEpisodeBuffers() {
        EpisodeManager.cleanupAllUnusedEpisodeBuffers()
    }

    func episodeCanBeCleanedUp(episode: Episode) -> Bool {
        episode.episodeCanBeCleanedUp()
    }

    func performActionsAfterRefresh() {
        cleanupNetworkDataUsageIfNeeded()
        PodcastManager.shared.checkForPendingAndAutoDownloads()
        PlaylistManager.checkForAutoDownloads()
    }

    private func cleanupNetworkDataUsageIfNeeded() {
        guard FeatureFlag.trackNetworkDataUsage.enabled else { return }

        let defaults = UserDefaults.standard
        let lastCleanupDate = defaults.object(forKey: Constants.UserDefaults.lastNetworkDataUsageCleanupDate) as? Date

        guard DateUtil.hasEnoughTimePassed(since: lastCleanupDate, time: Self.networkDataUsageCleanupInterval) else {
            return
        }

        let cleanupDate = Date()
        defaults.set(cleanupDate, forKey: Constants.UserDefaults.lastNetworkDataUsageCleanupDate)

        Task {
            let didCleanup = await DataManager.shared.networkDataUsageManager.deleteRecords(
                olderThan: Date(timeIntervalSinceNow: -Self.networkDataUsageRetentionPeriod)
            )

            if !didCleanup {
                defaults.set(lastCleanupDate, forKey: Constants.UserDefaults.lastNetworkDataUsageCleanupDate)
            }
        }
    }

    // MARK: - Settings

    func defaultPodcastGrouping() -> Int32 {
        Settings.defaultPodcastGrouping.rawValue
    }

    func defaultShowArchived() -> Bool {
        Settings.showArchivedDefault
    }

    func autoDownloadLatestEpisodes(uuids: [String]) {
        if Settings.autoDownloadEnabled() {
            if Settings.autoDownloadMobileDataAllowed() || NetworkUtils.shared.isConnectedToUnexpensiveConnection() {
                for uuid in uuids {
                    DownloadManager.shared.addToQueue(episodeUuid: uuid)
                }
            }
        }
    }
}
