import Foundation
import PocketCastsDataModel
import PocketCastsServer

/// Telemetry has been removed. Every method on the episode helper is a
/// no-op now. The class still inherits from AnalyticsCoordinator and
/// keeps `shared` so call sites continue to compile.
class AnalyticsEpisodeHelper: AnalyticsCoordinator {
    static var shared = AnalyticsEpisodeHelper()

    func setup() {}

    // MARK: - Star

    func star(episode: BaseEpisode) {}
    func bulkStar(count: Int) {}
    func unstar(episode: BaseEpisode) {}
    func bulkUnstar(count: Int) {}

    // MARK: - Download

    func downloadCancelled(episodeUUID: String) {}
    func downloaded(episodeUUID: String) {}
    func downloadFinished(episodeUUID: String) {}
    func downloadFailed(episodeUUID: String, podcastUUID: String, extraProperties: [String: Any]) {}
    func bulkDownloadEpisodes(episodes: [BaseEpisode]) {}
    func downloadDeleted(episode: BaseEpisode) {}
    func bulkDeleteDownloadedEpisodes(count: Int) {}

    // MARK: - Mark Played

    func markAsPlayed(episode: BaseEpisode) {}
    func bulkMarkAsPlayed(count: Int) {}
    func markAsUnplayed(episode: BaseEpisode) {}
    func bulkMarkAsUnplayed(count: Int) {}
    func bulkRemoveFromListeningHistory(count: Int) {}

    // MARK: - Archive

    func archiveEpisode(_ episode: BaseEpisode) {}
    func bulkArchiveEpisodes(count: Int) {}
    func unarchiveEpisode(_ episode: BaseEpisode) {}
    func bulkUnarchiveEpisodes(count: Int) {}

    // MARK: - Upload

    func episodeUploaded(episodeUUID: String) {}
    func episodeUploadCancelled(episodeUUID: String) {}
    func episodeDeletedFromCloud(episode: BaseEpisode) {}
    func episodeUploadFinished(episodeUUID: String) {}
    func episodeUploadFailed(episodeUUID: String) {}

    // MARK: - Up Next

    func episodeAddedToUpNext(episode: BaseEpisode, toTop: Bool) {}
    func bulkAddToUpNext(count: Int, toTop: Bool) {}
    func episodeRemovedFromUpNext(episode: BaseEpisode) {}

    // MARK: - Internal source-cache surface (still touched by callers)

    func cacheDownloadSource(for episodeUUID: String) -> AnalyticsSource {
        .unknown
    }

    func cacheDownloadSource(for episodeUUIDs: [String]) -> AnalyticsSource {
        .unknown
    }

    func consumeDownloadSource(for episodeUUID: String) -> AnalyticsSource? {
        nil
    }

    func clearDownloadSource(for episodeUUID: String) {}

    func episodeEvent(_ event: AnalyticsEvent, episode: BaseEpisode? = nil, uuid: String? = nil) {}

    func bulkEvent(_ event: AnalyticsEvent, count: Int) {}
}
