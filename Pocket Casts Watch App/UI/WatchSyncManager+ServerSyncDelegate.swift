import Foundation
import PocketCastsDataModel
import PocketCastsServer

extension WatchSyncManager: ServerSyncDelegate {
    // MARK: - Podcast functions

    func podcastAdded(podcastUuid: String) {
        NotificationCenter.postOnMainThread(notification: Constants.Notifications.podcastAdded, object: podcastUuid)
    }

    func checkForUnusedPodcasts() {
        Task {
            await PodcastManager.shared.checkForUnusedPodcasts()
        }
    }

    func applyAutoArchivingToAllPodcasts() {}

    // MARK: - Episode functions

    func cleanupAllUnusedEpisodeBuffers() {
        EpisodeManager.cleanupAllUnusedEpisodeBuffers()
    }

    func episodeCanBeCleanedUp(episode: Episode) -> Bool {
        episode.episodeCanBeCleanedUp()
    }

    func performActionsAfterRefresh() {}

    func autoDownloadLatestEpisodes(uuids: [String]) {}

    // MARK: - Settings

    func defaultPodcastGrouping() -> Int32 {
        Settings.defaultPodcastGrouping.rawValue
    }

    func defaultShowArchived() -> Bool {
        Settings.showArchivedDefault
    }
}
