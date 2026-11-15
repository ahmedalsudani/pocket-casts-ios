import Foundation
import PocketCastsDataModel
import PocketCastsUtils

public class RefreshManager {
    public static let shared = RefreshManager()

    lazy var refreshQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1

        return queue
    }()

    // the watch has less resources than a phone, so be a bit more aggressive about not refreshing constantly
    #if os(watchOS)
        private static let minTimeBetweenRefreshes = 1.minute
    #else
        private static let minTimeBetweenRefreshes = 15.seconds
    #endif

    /// Re-reads a single podcast's feed and adds any episodes it has that we don't. Returns whether it found any.
    @discardableResult
    public func refresh(podcast: Podcast) async -> Bool {
        // only followed podcasts take part in a refresh, the others are brought up to date in place
        guard podcast.isSubscribed() else {
            return await withCheckedContinuation { continuation in
                ServerPodcastManager.shared.updatePodcastIfRequired(podcast: podcast, addMissingEpisodes: true) { updated in
                    continuation.resume(returning: updated)
                }
            }
        }

        return await withCheckedContinuation { continuation in
            refresh(podcasts: [podcast]) { result in
                continuation.resume(returning: result == .newData)
            }
        }
    }

    public func refreshPodcasts(forceEvenIfRefreshedRecently: Bool = false) {
        if !forceEvenIfRefreshedRecently {
            if let lastRefreshStartTime = ServerSettings.lastRefreshStartTime(), fabs(lastRefreshStartTime.timeIntervalSinceNow) < RefreshManager.minTimeBetweenRefreshes {
                // if it's been less than minTimeBetweenRefreshes since our last refresh, don't do another one. Effectively throttling user refreshes a little bit
                FileLog.shared.addMessage("Refresh - Throttled")
                DispatchQueue.global().async {
                    Thread.sleep(forTimeInterval: 1.second)
                    ServerNotificationsHelper.shared.firePodcastsUpdated()
                    NotificationCenter.default.post(name: ServerNotifications.podcastRefreshThrottled, object: nil)
                }

                return
            }
        }

        UserDefaults.standard.set(Date(), forKey: ServerConstants.UserDefaults.lastRefreshStartTime)
        refresh(podcasts: DataManager.shared.allPodcasts(includeUnsubscribed: false), completion: nil)
    }

    public func refreshPodcasts(completion: @escaping (RefreshFetchResult) -> Void) {
        DispatchQueue.global().async { [self] in
            refresh(podcasts: DataManager.shared.allPodcasts(includeUnsubscribed: false), completion: completion)
        }
    }

    public func cancelAllRefreshes() {
        refreshQueue.cancelAllOperations()
    }

    /// Fetches the feeds of the given podcasts, then queues up the work of saving what was found.
    ///
    /// `self` is captured strongly on purpose: this is a singleton, and watchOS 10 kills the app when a
    /// refresh started here captures it weakly.
    private func refresh(podcasts: [Podcast], completion: ((RefreshFetchResult) -> Void)?) {
        FileLog.shared.addMessage("Refresh - Started")

        for podcast in podcasts { // ensure podcasts have up to date latest episode uuids
            ServerPodcastManager.shared.updateLatestEpisodeInfo(podcast: podcast, setDefaults: false)
        }

        Task { [self] in
            let response = await LocalFeedService.shared.refresh(podcasts: podcasts)
            refreshQueue.addOperation(RefreshOperation(result: response.result ?? RefreshResult(), completionHandler: completion))
        }
    }
}
