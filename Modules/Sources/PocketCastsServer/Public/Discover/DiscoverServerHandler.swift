import Combine
import Foundation
import PocketCastsUtils

public protocol DiscoverServerHandling {
    func discoverCategories(source: String, authenticated: Bool?) async -> [DiscoverCategory]
}

/// All Discover content lived on the Pocket Casts server (`static.pocketcasts.com`
/// / `api.pocketcasts.com`). With the server gone, this handler returns empty
/// data immediately — no network calls — so callers degrade to empty-state UI.
/// The thumbnail URL builder is preserved for now; image fetching from those
/// CDN paths is part of a separate cleanup.
public class DiscoverServerHandler: DiscoverServerHandling {
    enum DiscoverServerError: Error {
        case unknown
        case badRequest
    }

    public static let shared = DiscoverServerHandler()

    public private(set) lazy var discoveryCache: URLCache = {
        let cache = URLCache(memoryCapacity: 1024 * 1024, diskCapacity: 5 * 1024 * 1024, diskPath: "discovery")
        return cache
    }()

    /// Valid image sizes: 130,140,200,210,280,340,400,420,680,960
    public class func thumbnailUrl(forPodcast podcast: String, size: Int) -> URL {
        URL(string: thumbnailUrlString(forPodcast: podcast, size: size))!
    }

    public class func thumbnailUrlString(forPodcast podcast: String, size: Int) -> String {
        "\(ServerConstants.Urls.discover())images/\(size)/\(podcast).jpg"
    }

    public func discoverPage() async -> (DiscoverLayout?, Bool) {
        (nil, false)
    }

    public func discoverPage(completion: @escaping (DiscoverLayout?, Bool) -> Void) {
        completion(nil, false)
    }

    public func discoverNetworkList(source: String, authenticated: Bool?, completion: @escaping ([PodcastNetwork]?) -> Void) {
        completion(nil)
    }

    public func discoverPodcastList(source: String, authenticated: Bool?, completion: @escaping (PodcastList?) -> Void) {
        completion(nil)
    }

    public func discoverCategories(source: String, authenticated: Bool?, completion: @escaping ([DiscoverCategory]?) -> Void) {
        completion(nil)
    }

    public func discoverCategories(source: String, authenticated: Bool?) async -> [DiscoverCategory] {
        []
    }

    public func discoverCategoryDetails(source: String, authenticated: Bool?, completion: @escaping (DiscoverCategoryDetails?) -> Void) {
        completion(nil)
    }

    public func discoverCategoryDetails(source: String, authenticated: Bool?) async -> DiscoverCategoryDetails? {
        nil
    }

    public func discoverPodcastCollection(source: String, authenticated: Bool?, completion: @escaping (PodcastCollection?) -> Void) {
        completion(nil)
    }

    public func discoverItem<T>(_ source: String?, authenticated: Bool, type: T.Type) -> AnyPublisher<T, Error> where T: Decodable {
        Fail(error: DiscoverServerError.unknown).eraseToAnyPublisher()
    }

    public func checkSourceAuthentication(for item: DiscoverItem) async -> Bool {
        false
    }

    public func cachedResponse(for path: String) -> CachedURLResponse? {
        nil
    }
}
