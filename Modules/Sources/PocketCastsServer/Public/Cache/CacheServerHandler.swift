import Foundation
import PocketCastsDataModel

/// All cache-server endpoints (cache.pocketcasts.com) are gone. This handler
/// is kept as a no-op shim so call sites (addFromUuid, theme colour loaders,
/// podcast-scoped episode search) stay compilable. They now degrade to "no
/// data" — addFromUuid falls back to a local-feed refresh when the podcast
/// already exists, and theme colours fall back to defaults.
public class CacheServerHandler {
    public static let shared = CacheServerHandler()

    public static let noShowNotesMessage = "Unable to find show notes for this episode."

    public init() {}

    // MARK: - Episode Artwork

    public func loadPodcastColors(podcastUuid: String, allowCachedVersion: Bool, completion: @escaping ((String?, String?, String?) -> Void)) {
        completion(nil, nil, nil)
    }

    // MARK: - Podcast Info

    public func loadPodcastInfo(podcastUuid: String, completion: @escaping (([String: Any]?, String?) -> Void)) {
        completion(nil, nil)
    }

    public func loadEpisodeUrl(episodeUuid: String, podcastUuid: String, completion: @escaping ((String?) -> Void)) {
        completion(nil)
    }

    public func loadPodcastIfModified(podcast: Podcast, completion: @escaping (([String: Any]?, String?) -> Void)) {
        completion(nil, nil)
    }

    // MARK: - Episode Search

    public struct EpisodeSearchQuery: Codable {
        let podcastuuid: String
        let searchterm: String

        public init(podcastUuid: String, searchTerm: String) {
            podcastuuid = podcastUuid
            searchterm = searchTerm
        }
    }

    public struct EpisodeSearchResult: Codable {
        public let episodes: [SearchResultEpisodes]
    }

    public struct SearchResultEpisodes: Codable {
        public let uuid: String
    }

    public func searchEpisodesInPodcast(search: EpisodeSearchQuery, completion: ((EpisodeSearchResult?) -> Void)?) {
        completion?(nil)
    }
}
