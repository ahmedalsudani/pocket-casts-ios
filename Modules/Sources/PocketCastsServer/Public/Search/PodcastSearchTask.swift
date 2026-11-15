import Foundation
import PocketCastsDataModel

public struct PodcastFolderSearchResult: Codable, Hashable {
    public let uuid: String
    public let title: String?
    public let author: String?
    public let kind: Kind
    public var isLocal: Bool?
    public var explicit: Bool?
    public var isVideo: Bool?

    enum CodingKeys: String, CodingKey {
        case uuid, title, author, kind, isLocal, explicit, isVideo
    }

    public init(uuid: String, title: String?, author: String?, kind: Kind = .podcast, isLocal: Bool? = false, explicit: Bool? = nil, isVideo: Bool? = nil) {
        self.uuid = uuid
        self.title = title
        self.author = author
        self.kind = kind
        self.isLocal = isLocal
        self.explicit = explicit
        self.isVideo = isVideo
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.uuid = try container.decode(String.self, forKey: .uuid)
        self.title = try? container.decode(String.self, forKey: .title)
        self.author = try? container.decode(String.self, forKey: .author)
        self.kind = (try? container.decodeIfPresent(Kind.self, forKey: .kind)) ?? .podcast
        self.isLocal = (try? container.decode(Bool.self, forKey: .isLocal)) ?? false
        self.explicit = try? container.decodeIfPresent(Bool.self, forKey: .explicit)
        self.isVideo = try? container.decodeIfPresent(Bool.self, forKey: .isVideo)
    }

    public init?(from podcast: Podcast) {
        self.uuid = podcast.uuid
        self.title = podcast.title
        self.author = podcast.author
        self.isLocal = true
        self.kind = .podcast
        self.explicit = podcast.isExplicit
        self.isVideo = nil
    }

    public init?(from folder: Folder) {
        self.uuid = folder.uuid
        self.title = folder.name
        self.author = ""
        self.isLocal = true
        self.kind = .folder
        self.explicit = false
        self.isVideo = false
    }

    public enum Kind: Codable {
        case podcast, folder
    }

    public static func ==(lhs: PodcastFolderSearchResult, rhs: PodcastFolderSearchResult) -> Bool {
        lhs.kind == rhs.kind && lhs.uuid == rhs.uuid
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(kind)
        hasher.combine(uuid)
    }
}

extension PodcastFolderSearchResult: Identifiable {
    public var id: String {
        "\(kind)-\(uuid)"
    }
}

public class PodcastSearchTask {
    public init() {}

    /// Searches Apple's podcast directory. A term that is itself a URL is treated as a feed address and
    /// fetched directly, since a directory would only text-match it.
    public func search(term: String) async throws -> [PodcastFolderSearchResult] {
        let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
        if Self.isURL(trimmed), let feedURL = URL(string: trimmed) {
            return await searchByFeedURL(feedURL)
        }
        return try await iTunesSearchService.shared.search(term: trimmed)
    }

    static func isURL(_ term: String) -> Bool {
        let lowercased = term.lowercased()
        return lowercased.hasPrefix("http://") || lowercased.hasPrefix("https://")
    }

    /// Fetches the feed and stores it as a podcast that isn't followed yet, so the result can be opened
    /// and followed like any other.
    private func searchByFeedURL(_ feedURL: URL) async -> [PodcastFolderSearchResult] {
        await withCheckedContinuation { continuation in
            ServerPodcastManager.shared.addFromFeedURL(feedURL, subscribe: false) { added, uuid in
                guard added, let uuid,
                      let podcast = DataManager.shared.findPodcast(uuid: uuid, includeUnsubscribed: true) else {
                    continuation.resume(returning: [])
                    return
                }
                continuation.resume(returning: [PodcastFolderSearchResult(uuid: uuid, title: podcast.title, author: podcast.author, explicit: podcast.isExplicit)])
            }
        }
    }
}
