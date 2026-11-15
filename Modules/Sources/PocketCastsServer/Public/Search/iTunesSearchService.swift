import Foundation
import PocketCastsUtils

/// Searches Apple's iTunes Search API for podcasts. Apple's API is rate-limited
/// (~20 calls/min/IP) but is otherwise free and requires no auth.
public class iTunesSearchService {
    public static let shared = iTunesSearchService()

    private let connection: URLConnection

    public init(connection: URLConnection = URLConnection(handler: URLSession.shared)) {
        self.connection = connection
    }

    public func search(term: String) async throws -> [PodcastFolderSearchResult] {
        let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        var components = URLComponents(string: "https://itunes.apple.com/search")
        components?.queryItems = [
            URLQueryItem(name: "term", value: trimmed),
            URLQueryItem(name: "entity", value: "podcast"),
            URLQueryItem(name: "limit", value: "50")
        ]

        guard let url = components?.url else { return [] }

        var request = URLRequest(url: url, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 15)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: ServerConstants.HttpHeaders.accept)

        let (data, _) = try await connection.send(request: request)
        guard let data,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = json["results"] as? [[String: Any]] else {
            return []
        }

        var seen = Set<String>()
        return results.compactMap { item -> PodcastFolderSearchResult? in
            guard let feedUrl = item["feedUrl"] as? String else { return nil }

            // Remember the feed and artwork, so the result can be shown and followed by its UUID
            let artworkUrl = item["artworkUrl600"] as? String ?? item["artworkUrl100"] as? String
            let uuid = DiscoveredPodcasts.shared.add(feedUrl: feedUrl, artworkUrl: artworkUrl)
            guard seen.insert(uuid).inserted else { return nil }

            return PodcastFolderSearchResult(
                uuid: uuid,
                title: item["collectionName"] as? String ?? item["trackName"] as? String,
                author: item["artistName"] as? String,
                explicit: (item["collectionExplicitness"] as? String).map { $0 == "explicit" }
            )
        }
    }
}
