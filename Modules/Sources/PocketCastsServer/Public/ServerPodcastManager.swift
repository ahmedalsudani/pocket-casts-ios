import Foundation
import PocketCastsDataModel
import PocketCastsUtils

public class ServerPodcastManager: NSObject {
    public static let shared = ServerPodcastManager()

    lazy var subscribeQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1

        return queue
    }()

    // MARK: - Podcast add functions

    /// Adds a podcast we already know the feed for: one in the database, or one seen in this session's search results.
    /// There is no directory to resolve any other UUID, so those fail.
    public func addFromUuid(podcastUuid: String, subscribe: Bool, autoDownloads: Int = 0, completion: ((Bool) -> Void)?) {
        guard let feedURL = feedURL(forPodcastUuid: podcastUuid) else {
            FileLog.shared.addMessage("ServerPodcastManager: no feed known for podcast \(podcastUuid), can't add it")
            completion?(false)
            return
        }

        addFromFeedURL(feedURL, subscribe: subscribe, autoDownloads: autoDownloads) { added, _ in
            completion?(added)
        }
    }

    /// Adds a podcast from its feed. The UUID is derived from the feed URL, so the same feed always resolves
    /// to the same podcast row. The completion receives that UUID when the podcast was added.
    public func addFromFeedURL(_ feedURL: URL, subscribe: Bool, autoDownloads: Int = 0, completion: ((Bool, String?) -> Void)?) {
        Task { [weak self] in
            guard let self else { return }
            await self.addFromFeedURLAsync(feedURL, subscribe: subscribe, autoDownloads: autoDownloads, completion: completion)
        }
    }

    private func addFromFeedURLAsync(_ feedURL: URL, subscribe: Bool, autoDownloads: Int, completion: ((Bool, String?) -> Void)?) async {
        let feedURLString = feedURL.absoluteString
        let podcastUuid = DiscoveredPodcasts.uuid(forFeedUrl: feedURLString)

        // A podcast we already hold doesn't need its feed fetched again just to follow it
        if let existing = DataManager.shared.findPodcast(uuid: podcastUuid, includeUnsubscribed: true) {
            subscribeQueue.addOperation { [weak self] in
                guard let self else { return }
                let added = self.addExisting(podcast: existing, subscribe: subscribe, autoDownloads: autoDownloads)
                completion?(added, added ? podcastUuid : nil)
            }
            return
        }

        do {
            let result = try await LocalFeedService.shared.fetch(feedURL: feedURL)
            switch result {
            case .notModified:
                completion?(false, nil)
            case .success(let feed, let lastModified, _):
                let info = feed.toPodcastInfoJson(uuid: podcastUuid, feedURLString: feedURLString)
                addFromJson(podcastUuid: podcastUuid, lastModified: lastModified, podcastInfo: info, subscribe: subscribe, autoDownloads: autoDownloads) { added in
                    completion?(added, added ? podcastUuid : nil)
                }
            }
        } catch {
            FileLog.shared.addMessage("ServerPodcastManager: feed fetch failed for \(feedURLString): \(error.localizedDescription)")
            completion?(false, nil)
        }
    }

    func addFromJson(podcastUuid: String, lastModified: String?, podcastInfo: [String: Any], subscribe: Bool, autoDownloads: Int, completion: ((Bool) -> Void)?) {
        let episodes = Self.episodes(fromPodcastInfo: podcastInfo)
        subscribeQueue.addOperation { [weak self] in
            guard let strongSelf = self else { return }

            let added = strongSelf.addPodcast(podcastInfo: podcastInfo, episodes: episodes, subscribe: subscribe, autoDownloads: autoDownloads, lastModified: lastModified)
            completion?(added)
        }
    }

    /// Finds an episode we don't hold yet by re-reading its podcast's feed. Only podcasts whose feed we know can be
    /// searched, and the episode has to still be in that feed.
    @discardableResult
    public func addMissingPodcastAndEpisode(episodeUuid: String, podcastUuid: String, shouldUpdateEpisode: Bool = false) async throws -> Episode? {
        if !shouldUpdateEpisode, let episode = DataManager.shared.findEpisode(uuid: episodeUuid) {
            return episode
        }

        guard let feedURL = feedURL(forPodcastUuid: podcastUuid) else {
            return DataManager.shared.findEpisode(uuid: episodeUuid)
        }

        do {
            guard case .success(let feed, let lastModified, _) = try await LocalFeedService.shared.fetch(feedURL: feedURL) else {
                return DataManager.shared.findEpisode(uuid: episodeUuid)
            }

            let info = feed.toPodcastInfoJson(uuid: podcastUuid, feedURLString: feedURL.absoluteString)

            // Ensure podcast is added, otherwise episode won't be
            if DataManager.shared.findPodcast(uuid: podcastUuid, includeUnsubscribed: true) == nil {
                _ = addPodcast(podcastInfo: info, episodes: Self.episodes(fromPodcastInfo: info), subscribe: false, lastModified: lastModified)
            }

            return addEpisode(uuid: episodeUuid, podcastInfo: info, shouldUpdate: shouldUpdateEpisode)
        } catch {
            FileLog.shared.addMessage("ServerPodcastManager: failed to load missing episode \(episodeUuid): \(error)")
            throw error
        }
    }

    private func feedURL(forPodcastUuid podcastUuid: String) -> URL? {
        let stored = DataManager.shared.findPodcast(uuid: podcastUuid, includeUnsubscribed: true)?.feedUrl
        guard let feedUrl = stored ?? DiscoveredPodcasts.shared.feedUrl(forUuid: podcastUuid) else { return nil }

        return URL(string: feedUrl)
    }

    /// Parses the podcast's episodes without a `podcast_id`, which `addPodcast` sets once the podcast is saved.
    private static func episodes(fromPodcastInfo podcastInfo: [String: Any]) -> [Episode]? {
        guard let podcastJson = podcastInfo["podcast"] as? [String: Any],
              let podcastUuid = podcastJson["uuid"] as? String,
              let episodesJson = podcastJson["episodes"] as? [[String: Any]] else { return nil }

        return episodesJson.map { Episode.from(episodeJson: $0, podcastId: 0, podcastUuid: podcastUuid) }
    }

    private func addExisting(podcast existingPodcast: Podcast, subscribe: Bool, autoDownloads: Int) -> Bool {
        if existingPodcast.isSubscribed(), subscribe { return true }

        if !existingPodcast.isSubscribed(), subscribe {
            // we have this podcast, just in a non-subscribed state, so subscribe to it
            existingPodcast.subscribed = 1
            existingPodcast.autoDownloadSetting = (autoDownloads > 0 ? AutoDownloadSetting.latest : AutoDownloadSetting.off).rawValue
        }
        DataManager.shared.save(podcast: existingPodcast)
        updateLatestEpisodeInfo(podcast: existingPodcast, setDefaults: true, autoDownloadLimit: autoDownloads)

        ServerConfig.shared.syncDelegate?.podcastAdded(podcastUuid: existingPodcast.uuid)

        return true
    }

    private func addPodcast(podcastInfo: [String: Any], episodes: [Episode]?, subscribe: Bool, autoDownloads: Int = 0, lastModified: String?) -> Bool {
        guard let podcastJson = podcastInfo["podcast"] as? [String: Any], let podcastUuid = podcastJson["uuid"] as? String else { return false }

        // check if we already have this podcast, and if we do treat it differently
        if let existingPodcast = DataManager.shared.findPodcast(uuid: podcastUuid, includeUnsubscribed: true) {
            return addExisting(podcast: existingPodcast, subscribe: subscribe, autoDownloads: autoDownloads)
        }

        let podcast = Podcast.from(podcastJson: podcastJson, podcastInfo: podcastInfo, uuid: podcastUuid, subscribe: subscribe, autoDownloads: autoDownloads, lastModified: lastModified)

        podcast.sortOrder = highestSortOrderForHomeGrid() + 1

        // we don't accept podcasts with no episodes
        guard let episodes, !episodes.isEmpty else { return false }

        // save the podcast so that it gets and ID
        DataManager.shared.save(podcast: podcast)

        for episode in episodes {
            episode.podcast_id = podcast.id
        }
        DataManager.shared.bulkSave(episodes: episodes)

        updateLatestEpisodeInfo(podcast: podcast, setDefaults: subscribe, autoDownloadLimit: autoDownloads)

        if subscribe {
            ServerConfig.shared.syncDelegate?.podcastAdded(podcastUuid: podcast.uuid)
        }

        return true
    }

    private func addEpisode(uuid: String, podcastInfo: [String: Any], shouldUpdate: Bool) -> Episode? {
        guard let podcastJson = podcastInfo["podcast"] as? [String: Any],
              let podcastUuid = podcastJson["uuid"] as? String,
              let episodesJson = podcastJson["episodes"] as? [[String: Any]],
              let podcast = DataManager.shared.findPodcast(uuid: podcastUuid, includeUnsubscribed: true),
              let episodeJson = episodesJson.first(where: { $0["uuid"] as? String == uuid }) else {
            return DataManager.shared.findEpisode(uuid: uuid)
        }

        if let episode = DataManager.shared.findEpisode(uuid: uuid) {
            if shouldUpdate {
                let updatedEpisode = Episode.from(episodeJson: episodeJson, podcastId: podcast.id, podcastUuid: podcast.uuid)

                // Refresh feed-driven fields while preserving user state (playback, downloads, etc.)
                episode.title = updatedEpisode.title
                episode.downloadUrl = updatedEpisode.downloadUrl
                episode.fileType = updatedEpisode.fileType
                episode.sizeInBytes = updatedEpisode.sizeInBytes
                episode.duration = updatedEpisode.duration
                episode.publishedDate = updatedEpisode.publishedDate
                episode.episodeNumber = updatedEpisode.episodeNumber
                episode.seasonNumber = updatedEpisode.seasonNumber
                episode.episodeType = updatedEpisode.episodeType

                if episode.addedDate == nil {
                    episode.addedDate = updatedEpisode.addedDate
                }

                if episode.podcast_id == 0 {
                    episode.podcast_id = podcast.id
                }

                DataManager.shared.save(episode: episode)
            }
            return episode
        }

        let episode = Episode.from(episodeJson: episodeJson, podcastId: podcast.id, podcastUuid: podcast.uuid)

        DataManager.shared.save(episode: episode)

        return episode
    }

    public func highestSortOrderForHomeGrid() -> Int32 {
        homeGridSortOrder(highest: true)
    }

    public func lowestSortOrderForHomeGrid() -> Int32 {
        homeGridSortOrder(highest: false)
    }

    public func highestSortOrder(for folder: Folder) -> Int32 {
        let folderPodcasts = DataManager.shared.allPodcastsInFolder(folder: folder)
        var highest: Int32 = 1

        for podcast in folderPodcasts {
            if podcast.sortOrder > highest { highest = podcast.sortOrder }
        }

        return highest
    }

    private func homeGridSortOrder(highest: Bool) -> Int32 {
        let gridPodcasts = DataManager.shared.allPodcasts(includeUnsubscribed: false).filter { $0.folderUuid == nil }
        let allFolders = DataManager.shared.allFolders()
        var value: Int32 = highest ? 1 : 0

        for podcast in gridPodcasts {
            if highest, podcast.sortOrder > value { value = podcast.sortOrder }
            else if !highest, podcast.sortOrder < value { value = podcast.sortOrder }
        }

        for folder in allFolders {
            if highest, folder.sortOrder > value { value = folder.sortOrder }
            else if !highest, folder.sortOrder < value { value = folder.sortOrder }
        }

        return value
    }
}
