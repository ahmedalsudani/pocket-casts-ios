import Foundation
import PocketCastsDataModel

/// What the refresh needs from the app that hosts it
public protocol ServerSyncDelegate {
    func podcastAdded(podcastUuid: String)
    func checkForUnusedPodcasts()
    func applyAutoArchivingToAllPodcasts()

    func episodeCanBeCleanedUp(episode: Episode) -> Bool
    func autoDownloadLatestEpisodes(uuids: [String])
    func cleanupAllUnusedEpisodeBuffers()

    func performActionsAfterRefresh()

    func defaultPodcastGrouping() -> Int32
    func defaultShowArchived() -> Bool
}
