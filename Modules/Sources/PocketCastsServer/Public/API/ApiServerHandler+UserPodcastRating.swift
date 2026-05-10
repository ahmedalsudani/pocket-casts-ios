import Foundation
import PocketCastsDataModel

public extension ApiServerHandler {
    /// Ratings used to round-trip through `api.pocketcasts.com`. Returning
    /// false / nil makes the rating UI fall through to a hidden / read-only
    /// state.
    func addRating(uuid: String, rating: Int) async -> Bool {
        false
    }

    func getRating(uuid: String) async -> UserPodcastRating? {
        nil
    }
}
