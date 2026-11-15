import Foundation
import PocketCastsUtils

/// Podcasts seen this session that may not be in the database yet, such as search results.
///
/// A podcast's UUID is derived from its feed URL, so remembering the feed here is what lets the rest of the app
/// keep opening and following podcasts by UUID without anything to ask for the feed.
public final class DiscoveredPodcasts {
    public static let shared = DiscoveredPodcasts()

    private struct Entry {
        let feedUrl: String
        let artworkUrl: String?
    }

    private var entries = [String: Entry]()
    private let lock = NSLock()

    /// The UUID a podcast with this feed gets, however it is found.
    public static func uuid(forFeedUrl feedUrl: String) -> String {
        UUID.v5(namespace: .pocketCastsPodcastNamespace, name: feedUrl).uuidString.lowercased()
    }

    @discardableResult
    public func add(feedUrl: String, artworkUrl: String? = nil) -> String {
        let uuid = Self.uuid(forFeedUrl: feedUrl)
        lock.lock()
        defer { lock.unlock() }
        entries[uuid] = Entry(feedUrl: feedUrl, artworkUrl: artworkUrl ?? entries[uuid]?.artworkUrl)
        return uuid
    }

    public func feedUrl(forUuid uuid: String) -> String? {
        lock.lock()
        defer { lock.unlock() }
        return entries[uuid]?.feedUrl
    }

    public func artworkUrl(forUuid uuid: String) -> String? {
        lock.lock()
        defer { lock.unlock() }
        return entries[uuid]?.artworkUrl
    }
}
