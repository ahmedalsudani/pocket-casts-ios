import Foundation
import PocketCastsDataModel

public struct PodcastRating: Codable {
    public let total: Int
    public let average: Double
}

public struct PodcastRatingTask {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    /// Star ratings used to come from `cache.pocketcasts.com/podcast/rating/{uuid}`.
    /// With the cache server gone, ratings always return nil.
    public func retrieve(for podcastUuid: String, ignoringCache: Bool) async throws -> PodcastRating? {
        nil
    }
}
