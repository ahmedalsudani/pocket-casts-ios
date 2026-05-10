import Foundation

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

    /// Cross-catalog episode search lived on `cache.pocketcasts.com`. It has
    /// no on-device equivalent — there's no global episode index without a
    /// server. Returns an empty list; the search UI degrades gracefully.
    public func search(term: String) async throws -> [EpisodeSearchResult] {
        []
    }
}
