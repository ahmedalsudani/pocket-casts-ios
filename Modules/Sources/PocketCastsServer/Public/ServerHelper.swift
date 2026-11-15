import Foundation
import PocketCastsDataModel
import PocketCastsUtils

public enum ServerHelper {
    /// A podcast's artwork is whatever image its feed names. Podcasts that aren't in the database yet use the
    /// artwork their search result came with. The lookup is served from PodcastDataManager's in-memory cache,
    /// so it's safe in scroll paths.
    public static func imageUrl(podcastUuid: String, size: Int) -> URL {
        if let feedImage = DataManager.shared.findPodcast(uuid: podcastUuid, includeUnsubscribed: true)?.imageURL, !feedImage.isEmpty, let url = URL(string: feedImage) {
            return url
        }
        if let artwork = DiscoveredPodcasts.shared.artworkUrl(forUuid: podcastUuid), let url = URL(string: artwork) {
            return url
        }

        return unavailableArtworkUrl(for: podcastUuid)
    }

    public static func image(podcastUuid: String, size: Int) -> String {
        imageUrl(podcastUuid: podcastUuid, size: size).absoluteString
    }

    /// Files have no artwork of their own unless the user picks an image, so there is nothing to load for these.
    public static func userEpisodeDefaultImageUrl(isDark: Bool, color: Int, size: Int) -> URL {
        unavailableArtworkUrl(for: "file-\(color)")
    }

    /// A URL that never resolves to an image. Loading it fails without touching the network, which leaves
    /// callers showing their placeholder.
    public static func unavailableArtworkUrl(for identifier: String) -> URL {
        URL(fileURLWithPath: "/unavailable-artwork/\(identifier)")
    }
}
