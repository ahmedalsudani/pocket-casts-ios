import Foundation

struct CombinedSearchEnvelope: Decodable {
    public let results: [CombinedSearchResult]
}

public enum CombinedSearchResultType: Hashable {
    case episode(EpisodeSearchResult)
    case podcast(PodcastFolderSearchResult)
}

public struct CombinedSearchResult: Decodable, Hashable {
    public let type: String
    public let uuid: String
    public let title: String
    public let publishedDate: Date?
    public let duration: Double?
    public let podcastUuid: String?
    public let podcastTitle: String?
    public let author: String?

    public var resolvedResultType: CombinedSearchResultType? {
        switch type {
            case "podcast":
                guard let podcast = PodcastFolderSearchResult(from: self) else {
                    return nil
                }
                return .podcast(podcast)
            case "episode":
            let episode = EpisodeSearchResult(uuid: self.uuid, title: self.title, publishedDate: self.publishedDate ?? Date.now, state: .normal, duration: duration, podcastUuid: self.podcastUuid ?? "", podcastTitle: self.podcastTitle ?? "")
                return .episode(episode)
            default:
                return nil
        }
    }
}

public class CombinedSearchTask {
    private let session: URLSession
    private let episodeSearch = EpisodeSearchTask()

    public init(session: URLSession = .shared) {
        self.session = session
    }

    /// The combined podcast+episode endpoint lived on `cache.pocketcasts.com`.
    /// Podcast results come from iTunes Search now, and episode results from
    /// the local database (subscribed podcasts only).
    public func search(term: String) async throws -> [CombinedSearchResultType] {
        let podcasts = try await iTunesSearchService.shared.search(term: term)
        let episodes = (try? await episodeSearch.search(term: term)) ?? []
        return podcasts.map { CombinedSearchResultType.podcast($0) } + episodes.map { CombinedSearchResultType.episode($0) }
    }
}
