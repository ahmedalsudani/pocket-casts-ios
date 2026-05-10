import Foundation
import PocketCastsDataModel
import PocketCastsUtils
#if os(watchOS)
    import WatchKit
#else
    import UIKit
#endif

protocol BaseRequest: Encodable {
    var device: String? { get set }
    var m: String? { get set }
    var av: String? { get set }
    var l: String? { get set }
    var c: String? { get set }
    var dt: String? { get set }
    var v: String? { get set }
}

public class MainServerHandler {
    private static let callTimeout = 60.seconds

    public static let shared = MainServerHandler()

    private static let parserVersion = "1.7"
    private static let deviceType = "1"

    private lazy var securityDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMddHHmmss"

        return formatter
    }()

    private lazy var searchQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1

        return queue
    }()

    private let tokenHelper = TokenHelper.shared

    struct PodcastSearchQuery: BaseRequest {
        var q: String?
        var dt: String?
        var device: String?
        var v: String?
        var m: String?
        var av: String?
        var l: String?
        var c: String?
    }

    private struct PodcastUuidSearchQuery: BaseRequest {
        var id: Int?
        var dt: String?
        var device: String?
        var v: String?
        var m: String?
        var av: String?
        var l: String?
        var c: String?
    }

    private struct ShareListRequest: BaseRequest {
        var dt: String?
        var device: String?
        var v: String?
        var m: String?
        var av: String?
        var l: String?
        var c: String?
    }

    private struct ExportPodcastsRequest: BaseRequest {
        var uuids: [String]?
        var device: String?
        var m: String?
        var av: String?
        var l: String?
        var c: String?
        var dt: String?
        var v: String?
    }

    private struct UploadOpmlRequest: BaseRequest {
        var urls: [String]?
        var pollUuids: [String]?
        var device: String?
        var m: String?
        var av: String?
        var l: String?
        var c: String?
        var dt: String?
        var v: String?

        public enum CodingKeys: String, CodingKey {
            case urls, pollUuids = "poll_uuids", device, m, av, l, c, dt, v
        }
    }

    /// OPML import used to round-trip through `refresh.pocketcasts.com`. With
    /// the server gone, OpmlImporter parses URLs locally and calls
    /// `addFromFeedURL` directly — this entry point is unused.
    public func sendOpmlChunk(feedUrls: [String] = [], pollUuids: [String] = [], completion: @escaping (ImportOpmlResponse?) -> Void) {
        completion(ImportOpmlResponse.failedResponse())
    }

    /// OPML export used to ask the server to assemble feed URLs from a list
    /// of UUIDs. With the server gone, on-device export should iterate
    /// `Podcast.podcastUrl` directly.
    public func exportPodcasts(uuids: [String], completion: @escaping (ExportPodcastsResponse?) -> Void) {
        completion(ExportPodcastsResponse.failedResponse())
    }

    /// Share-link resolution lived on the Pocket Casts server. Returning a
    /// failed response makes share-link consumers degrade to "not found".
    public func lookupShareLink(sharePath: String, completion: @escaping (ShareListResponse?) -> Void) {
        completion(ShareListResponse.failedResponse())
    }

    public func refresh(podcasts: [Podcast], completion: @escaping (PodcastRefreshResponse?) -> Void) {
        FileLog.shared.addMessage("Refresh - Started (local feed service)")
        for podcast in podcasts { // ensure podcasts have up to date latest episode uuids
            ServerPodcastManager.shared.updateLatestEpisodeInfo(podcast: podcast, setDefaults: false)
        }
        Task {
            let response = await LocalFeedService.shared.refresh(podcasts: podcasts)
            completion(response)
        }
    }

    /// Returns nil — the background URL session refresh path that used this
    /// has been replaced by a direct LocalFeedService refresh in
    /// BackgroundSyncManager.
    public func createRefreshRequest(podcasts: [Podcast]) -> URLRequest? {
        nil
    }

    /// Server-backed podcast search is gone. Use `PodcastSearchTask` /
    /// `iTunesSearchService` instead.
    public func podcastSearch(searchTerm: String, completion: @escaping (PodcastSearchResponse?) -> Void) {
        completion(PodcastSearchResponse.failedResponse())
    }

    func podcastSearchQuery(searchTerm: String) -> PodcastSearchQuery? {
        guard let uniqueId = ServerConfig.shared.syncDelegate?.uniqueAppId() else {
            return nil
        }

        var baseQuery: BaseRequest = PodcastSearchQuery()
        addStandardParams(baseRequest: &baseQuery, uniqueId: uniqueId)

        var searchQuery = baseQuery as! PodcastSearchQuery
        searchQuery.q = searchTerm

        return searchQuery
    }

    public func refreshPodcastFeed(podcast: Podcast, completion: @escaping (Bool) -> Void) {
        FileLog.shared.addMessage("Attempting to refresh feed locally for \(podcast.uuid)")
        refresh(podcasts: [podcast]) { response in
            completion(response?.success() == true)
        }
    }

    /// iTunes-id resolution now lives in `LocalFeedService.iTunesLookup`,
    /// which returns the publisher's RSS feed URL directly.
    public func findPodcastByiTunesId(_ iTunesId: Int, completion: @escaping (String?) -> Void) {
        completion(nil)
    }

    /// `updatePodcast` used to ask the Pocket Casts server to re-pull a
    /// podcast's feed. With the local feed pipeline we just refresh that
    /// podcast directly and report success.
    public func updatePodcast(uuid: String, lastEpisodeUuid: String?) async throws -> Bool {
        guard let podcast = DataManager.sharedManager.findPodcast(uuid: uuid, includeUnsubscribed: true) else {
            return false
        }
        await withCheckedContinuation { continuation in
            refreshPodcastFeed(podcast: podcast) { _ in
                continuation.resume()
            }
        }
        return true
    }

    private func jsonWithStandardParams(uniqueId: String) -> [String: Any] {
        var json: [String: Any] = [:]
        let locale = Locale.current
        json["l"] = locale.language.languageCode?.identifier
        json["c"] = locale.region?.identifier

        #if os(watchOS)
            json["m"] = WKInterfaceDevice.current().systemVersion
        #else
            json["m"] = UIDevice.current.systemVersion
        #endif

        json["dt"] = MainServerHandler.deviceType
        json["v"] = MainServerHandler.parserVersion
        json["device"] = uniqueId
        json["av"] = ServerConfig.shared.syncDelegate?.appVersion()

        return json
    }

    private func addStandardParams(baseRequest: inout BaseRequest, uniqueId: String) {
        let locale = Locale.current
        baseRequest.l = locale.language.languageCode?.identifier
        baseRequest.c = locale.region?.identifier

        #if os(watchOS)
            baseRequest.m = WKInterfaceDevice.current().systemVersion
        #else
            baseRequest.m = UIDevice.current.systemVersion
        #endif

        baseRequest.dt = MainServerHandler.deviceType
        baseRequest.v = MainServerHandler.parserVersion
        baseRequest.device = uniqueId
        baseRequest.av = ServerConfig.shared.syncDelegate?.appVersion()
    }
}
