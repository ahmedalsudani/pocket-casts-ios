import Foundation
import PocketCastsDataModel

struct EpisodeSearchEnvelope: Decodable {
    public let episodes: [EpisodeSearchResult]
}

public struct EpisodeSearchResult: Codable, Hashable {
    public let uuid: String
    public let title: String
    public let publishedDate: Date
    public let duration: Double?
    public let podcastUuid: String
    public let podcastTitle: String
    public let state: State?

    public init(uuid: String, title: String, publishedDate: Date, state: State? = nil, duration: Double? = nil, podcastUuid: String, podcastTitle: String) {
        self.uuid = uuid
        self.title = title
        self.publishedDate = publishedDate
        self.state = state
        self.duration = duration
        self.podcastUuid = podcastUuid
        self.podcastTitle = podcastTitle
    }

    public enum State: Codable {
        case normal
        case archived
        case unavailable

        public var isNormal: Bool {
            switch self {
            case .normal:
                true
            default:
                false
            }
        }
    }
}

public class EpisodeSearchTask {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    /// Cross-catalog episode search lived on `cache.pocketcasts.com`; without
    /// a server there's no global index, but every subscribed podcast's
    /// episodes are in the local database, so search those instead.
    public func search(term: String) async throws -> [EpisodeSearchResult] {
        let episodes = DataManager.sharedManager.findEpisodes(matching: term)
        guard !episodes.isEmpty else { return [] }

        let podcastTitles = DataManager.sharedManager.allPodcasts(includeUnsubscribed: false).reduce(into: [String: String]()) { $0[$1.uuid] = $1.title }

        return episodes.map { episode in
            EpisodeSearchResult(uuid: episode.uuid,
                                title: episode.title ?? "",
                                publishedDate: episode.publishedDate ?? episode.addedDate ?? .distantPast,
                                state: episode.archived ? .archived : .normal,
                                duration: episode.duration,
                                podcastUuid: episode.podcastUuid,
                                podcastTitle: podcastTitles[episode.podcastUuid] ?? "")
        }
    }
}
