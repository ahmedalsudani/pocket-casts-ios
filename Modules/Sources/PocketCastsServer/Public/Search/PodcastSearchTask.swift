import Foundation
import PocketCastsDataModel

struct PodcastsSearchEnvelope: Decodable {
    let status: String
    let message: String?
    let result: PodcastsSearchEnvelopeResult
}

struct PodcastsSearchEnvelopeResult: Decodable {
    /// Podcast returned when the user searches directly for a URL
    let podcast: PodcastFolderSearchResult?

    /// Regular search results based on a search term
    let searchResults: [PodcastFolderSearchResult]?

    /// The poll uuid if the result is still being processed on the server
    let pollUuid: String?
}

public struct PodcastFolderSearchResult: Codable, Hashable {
    public let uuid: String
    public let title: String?
    public let author: String?
    public let kind: Kind
    public var isLocal: Bool?
    public let iTunesId: Int?

    public init(uuid: String, title: String?, author: String?, kind: Kind, isLocal: Bool? = false, iTunesId: Int? = nil) {
        self.uuid = uuid
        self.title = title
        self.author = author
        self.kind = kind
        self.isLocal = isLocal
        self.iTunesId = iTunesId
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.uuid = try container.decode(String.self, forKey: .uuid)
        self.title = try? container.decode(String.self, forKey: .title)
        self.author = try? container.decode(String.self, forKey: .author)
        self.kind = (try? container.decodeIfPresent(Kind.self, forKey: .kind)) ?? .podcast
        self.isLocal = (try? container.decode(Bool.self, forKey: .isLocal)) ?? false
        self.iTunesId = try? container.decodeIfPresent(Int.self, forKey: .iTunesId)
    }

    public init?(from podcast: Podcast) {
        self.uuid = podcast.uuid
        self.title = podcast.title
        self.author = podcast.author
        self.isLocal = true
        self.kind = .podcast
        self.iTunesId = nil
    }

    public init?(from folder: Folder) {
        self.uuid = folder.uuid
        self.title = folder.name
        self.author = ""
        self.isLocal = true
        self.kind = .folder
        self.iTunesId = nil
    }

    public init?(from predictiveResult: PredictiveSearchResult) {
        switch predictiveResult.type {
            case .podcast(let podcast):
                self.uuid = podcast.uuid
                self.author = podcast.author
                self.title = podcast.title
                self.kind = .podcast
                self.isLocal = false
                self.iTunesId = nil
            default:
                return nil
        }

    }

    public init?(from combinedResult: CombinedSearchResult) {
        guard combinedResult.type == "podcast" else {
            return nil
        }
        self.uuid = combinedResult.uuid
        self.author = combinedResult.author
        self.title = combinedResult.title
        self.kind = .podcast
        self.isLocal = false
        self.iTunesId = nil
    }

    public enum Kind: Codable {
        case podcast, folder
    }

    static public func ==(lhs: PodcastFolderSearchResult, rhs: PodcastFolderSearchResult) -> Bool {
        lhs.kind == rhs.kind && lhs.uuid == rhs.uuid
    }
}

extension PodcastFolderSearchResult: Identifiable {
    public var id: String {
        uuid
    }
}

public class PodcastSearchTask {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    /// Routes podcast search through Apple's iTunes Search API instead of
    /// the (now-gone) Pocket Casts server. Each result carries an iTunesId
    /// so the subscribe flow can resolve the publisher's RSS feed URL via
    /// `iTunesLookup` and then call `addFromFeedURL`.
    ///
    /// A term that is itself a URL is treated as an RSS feed address (the old
    /// server handled this case by returning `PodcastsSearchEnvelopeResult.podcast`):
    /// the feed is fetched directly instead of being text-matched by iTunes.
    public func search(term: String) async throws -> [PodcastFolderSearchResult] {
        let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
        if isURL(trimmed), let feedURL = URL(string: trimmed) {
            return await searchByFeedURL(feedURL)
        }
        return try await iTunesSearchService.shared.search(term: trimmed)
    }

    private func isURL(_ term: String) -> Bool {
        let lowercased = term.lowercased()
        return lowercased.hasPrefix("http://") || lowercased.hasPrefix("https://")
    }

    /// Fetches the feed and stores it locally as an unsubscribed podcast, so
    /// opening or subscribing to the returned result resolves through
    /// `addFromUuid`'s local-first path (the cache server is gone).
    private func searchByFeedURL(_ feedURL: URL) async -> [PodcastFolderSearchResult] {
        await withCheckedContinuation { continuation in
            ServerPodcastManager.shared.addFromFeedURL(feedURL, subscribe: false) { added, uuid in
                guard added, let uuid,
                      let podcast = DataManager.sharedManager.findPodcast(uuid: uuid, includeUnsubscribed: true) else {
                    continuation.resume(returning: [])
                    return
                }
                continuation.resume(returning: [PodcastFolderSearchResult(uuid: uuid, title: podcast.title, author: podcast.author, kind: .podcast, isLocal: false, iTunesId: nil)])
            }
        }
    }
}

extension Int {
    // Return a correspondent poll waiting time for a given number
    // From 1 to 2: 2 seconds
    // From 3 to 6: 5 second
    // For 7: 10 seconds
    // Others: -1
    var pollWaitingTime: TimeInterval {
        switch self {
        case 1..<3:
            2
        case 3..<7:
            5
        case 7:
            10
        default:
            -1
        }
    }
}
