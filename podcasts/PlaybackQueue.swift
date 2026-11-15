import PocketCastsDataModel
import PocketCastsServer
import PocketCastsUtils
import UIKit

class PlaybackQueue: NSObject {
    // we get asked for this a lot, so might as well cache it
    private var topEpisode: BaseEpisode?

    // MARK: - Editing

    func remove(episode: BaseEpisode, fireNotification: Bool) {
        guard let episodeToRemove = DataManager.shared.findPlaylistEpisode(uuid: episode.uuid) else { return }

        FileLog.shared.addMessage("PlaybackQueue: removing \(episode.title ?? "Untitled") episode")
        DataManager.shared.delete(playlistEpisode: episodeToRemove)
        refreshAppFiring(notificationName: fireNotification ? Constants.Notifications.upNextEpisodeRemoved : nil, notificationObject: episode.uuid)
    }

    func remove(uuid: String, fireNotification: Bool) {
        guard let episodeToRemove = DataManager.shared.findPlaylistEpisode(uuid: uuid) else { return }

        FileLog.shared.addMessage("PlaybackQueue: removing \(episodeToRemove.title) episode")
        DataManager.shared.delete(playlistEpisode: episodeToRemove)
        refreshAppFiring(notificationName: fireNotification ? Constants.Notifications.upNextEpisodeRemoved : nil, notificationObject: uuid)
    }

    func removeTopEpisode(fireNotification: Bool) {
        guard let topEpisode else { return }

        FileLog.shared.addMessage("Remove Top Episode \(topEpisode.title ?? "Untitled")")
        remove(episode: topEpisode, fireNotification: fireNotification)
    }

    func add(episode: BaseEpisode, fireNotification: Bool, partOfBulkAdd: Bool = false, toTop: Bool = false) {
        if let existingEpisode = DataManager.shared.findPlaylistEpisode(uuid: episode.uuid) {
            existingEpisode.episodePosition = DataManager.shared.positionForPlaylistEpisode(bottomOfList: !toTop)
            DataManager.shared.save(playlistEpisode: existingEpisode)
        } else {
            let newEpisode = PlaylistEpisode()
            newEpisode.episodeUuid = episode.uuid
            newEpisode.episodePosition = DataManager.shared.positionForPlaylistEpisode(bottomOfList: !toTop)
            newEpisode.title = episode.displayableTitle()
            newEpisode.podcastUuid = episode.parentIdentifier()

            DataManager.shared.save(playlistEpisode: newEpisode)
        }

        // don't update until this bulk operation is complete
        if partOfBulkAdd { return }

        FileLog.shared.addMessage("PlaybackQueue: added single episode \(episode.title ?? "Untitled")")

        let notificationName = fireNotification ? Constants.Notifications.upNextEpisodeAdded : nil
        refreshAppFiring(notificationName: notificationName, notificationObject: episode.uuid, notificationUserInfo: [Constants.Notifications.upNextEpisodeAddedToTopKey: toTop])
    }

    func bulkOperationDidComplete() {
        FileLog.shared.addMessage("PlaybackQueue: finished bulk add")

        refreshAppFiring(notificationName: Constants.Notifications.upNextQueueChanged)
    }

    func bulkDelete(uuids: [String]) {
        DataManager.shared.deleteAllUpNextEpisodesIn(uuids: uuids)
        refreshAppFiring(notificationName: Constants.Notifications.upNextQueueChanged)
    }

    func bulkAdd(_ episodes: [BaseEpisode], toTop: Bool = false) {
        let topPosition = DataManager.shared.positionForPlaylistEpisode(bottomOfList: !toTop)
        var playlistEpisodes = [PlaylistEpisode]()
        for (index, episode) in episodes.enumerated() {
            if let existingEpisode = DataManager.shared.findPlaylistEpisode(uuid: episode.uuid) {
                existingEpisode.episodePosition = topPosition + Int32(index)
                playlistEpisodes.append(existingEpisode)
            } else {
                let newEpisode = PlaylistEpisode()
                newEpisode.episodeUuid = episode.uuid
                newEpisode.episodePosition = topPosition + Int32(index)
                newEpisode.title = episode.displayableTitle()
                newEpisode.podcastUuid = episode.parentIdentifier()
                playlistEpisodes.append(newEpisode)
            }
        }
        DataManager.shared.save(playlistEpisodes: playlistEpisodes)

        bulkOperationDidComplete()
    }

    func bulkMove(_ playlistEpisodes: [PlaylistEpisode], toTop: Bool) {
        let firstIndex = DataManager.shared.positionForPlaylistEpisode(bottomOfList: !toTop)
        for (index, playlistEpisode) in playlistEpisodes.enumerated() {
            playlistEpisode.episodePosition = Int32(index) + firstIndex
        }

        DataManager.shared.save(playlistEpisodes: playlistEpisodes)

        bulkOperationDidComplete()
    }

    func pushNewCurrentlyPlaying(episode: BaseEpisode) {
        if let existingEpisode = DataManager.shared.findPlaylistEpisode(uuid: episode.uuid) {
            DataManager.shared.movePlaylistEpisode(from: Int(existingEpisode.episodePosition), to: 0)
        } else {
            let newEpisode = PlaylistEpisode()
            newEpisode.episodeUuid = episode.uuid
            newEpisode.episodePosition = -1
            newEpisode.title = episode.displayableTitle()
            newEpisode.podcastUuid = episode.parentIdentifier()

            DataManager.shared.save(playlistEpisode: newEpisode)
            DataManager.shared.movePlaylistEpisode(from: -1, to: 0)
        }

        refreshAppFiring(notificationName: Constants.Notifications.upNextQueueChanged)
    }

    func moveEpisode(from: Int, to: Int) {
        // externally to the rest of the app, the now playing episode isn't in up next, so we need to increment these indexes
        DataManager.shared.movePlaylistEpisode(from: from + 1, to: to + 1)

        refreshAppFiring(notificationName: Constants.Notifications.upNextQueueChanged)
    }

    /// Reorders the Up Next queue to match `sortedEpisodes` (the queued episodes excluding now playing, which stays pinned at the top).
    func reorderUpNext(sortedEpisodes: [BaseEpisode]) {
        guard sortedEpisodes.count > 1 else { return }

        // Up Next playlist entries, excluding the now playing episode at index 0.
        var remaining = Array(DataManager.shared.allUpNextPlaylistEpisodes().dropFirst())
        var ordered = [PlaylistEpisode]()

        // Match the sorted episodes back to their playlist entries...
        for episode in sortedEpisodes {
            if let index = remaining.firstIndex(where: { $0.episodeUuid == episode.uuid }) {
                ordered.append(remaining.remove(at: index))
            }
        }
        // ...and keep any entries without metadata (e.g. not-yet-synced episodes) at the bottom.
        ordered.append(contentsOf: remaining)

        for (index, playlistEpisode) in ordered.enumerated() {
            // position 0 is the now playing episode, so the queue starts at 1
            playlistEpisode.episodePosition = Int32(index + 1)
        }
        DataManager.shared.save(playlistEpisodes: ordered)

        refreshAppFiring(notificationName: Constants.Notifications.upNextQueueChanged)
    }

    func insert(episode: BaseEpisode, position: Int) {
        let existingEpisode = contains(episode: episode)

        if existingEpisode {
            move(episode: episode, to: position)
        } else {
            let newEpisode = PlaylistEpisode()
            newEpisode.episodeUuid = episode.uuid
            newEpisode.episodePosition = Int32(position + 1)
            newEpisode.title = episode.displayableTitle()
            newEpisode.podcastUuid = episode.parentIdentifier()

            DataManager.shared.save(playlistEpisode: newEpisode)
        }

        refreshAppFiring(notificationName: Constants.Notifications.upNextQueueChanged)
    }

    func move(episode: BaseEpisode, to: Int, fireNotification: Bool = true) {
        guard let episodeToMove = DataManager.shared.findPlaylistEpisode(uuid: episode.uuid) else { return }

        // externally to the rest of the app, the now playing episode isn't in up next, so we need to increment this index
        DataManager.shared.movePlaylistEpisode(from: Int(episodeToMove.episodePosition), to: to + 1)

        refreshAppFiring(notificationName: fireNotification ? Constants.Notifications.upNextQueueChanged : nil)
    }

    func overrideAllEpisodesWith(episode: BaseEpisode) {
        FileLog.shared.addMessage("PlaybackQueue: overrideAllEpisodesWith with \(episode.title ?? "Untitled")")

        DataManager.shared.deleteAllUpNextEpisodes()
        pushNewCurrentlyPlaying(episode: episode)
    }

    func removeAllEpisodes() {
        DataManager.shared.snapshotUpNext()

        FileLog.shared.addMessage("PlaybackQueue: removeAllEpisodes called, clearing list")

        DataManager.shared.deleteAllUpNextEpisodes()

        topEpisode = nil

        NotificationCenter.postOnMainThread(notification: Constants.Notifications.upNextQueueChanged)
    }

    func clearUpNextList() {
        guard let topEpisode else { return }

        DataManager.shared.snapshotUpNext()

        DataManager.shared.deleteAllUpNextEpisodesExcept(episodeUuid: topEpisode.uuid)
        FileLog.shared.addMessage("PlaybackQueue: clearUpNextList called, clearing list")

        NotificationCenter.postOnMainThread(notification: Constants.Notifications.upNextQueueChanged)
    }

    func refreshList(checkForAutoDownload: Bool) {
        cacheTopEpisode()
        updateUpNextInfo()

        if checkForAutoDownload {
            checkAllForAutoDownload()
        }
    }

    func nowPlayingEpisodeChanged() {
        cacheTopEpisode()
        NotificationCenter.postOnMainThread(notification: Constants.Notifications.currentlyPlayingEpisodeUpdated)
    }

    // MARK: - Querying

    func contains(episode: BaseEpisode) -> Bool {
        contains(episodeUuid: episode.uuid)
    }

    func contains(episodeUuid: String) -> Bool {
        DataManager.shared.upNextPlayListContains(episodeUuid: episodeUuid)
    }

    func allEpisodes(includeNowPlaying: Bool = true) -> [BaseEpisode] {
        if includeNowPlaying { return DataManager.shared.allUpNextEpisodes() }

        var episodes = DataManager.shared.allUpNextEpisodes()
        if episodes.isEmpty { return episodes }

        episodes.removeFirst()

        return episodes
    }

    func currentEpisode() -> BaseEpisode? {
        topEpisode
    }

    func upNextCount() -> Int {
        // the data manager counts the current episode, so we remove it here, since we don't expose that info to the rest of the app
        max(0, DataManager.shared.playlistEpisodeCount() - 1)
    }

    func episodeAt(index: Int) -> BaseEpisode? {
        let actualIndex = index + 1 // the rest of the app doesn't treat the current episode as being at position 0
        if actualIndex < 0 { return nil }

        if let episode = DataManager.shared.episodeInUpNextAt(index: actualIndex) {
            return episode
        }

        guard let playlistEpisode = DataManager.shared.playlistEpisodeAt(index: actualIndex) else { return nil }

        let missingEpisode = UserEpisode()
        missingEpisode.title = playlistEpisode.title
        missingEpisode.uuid = playlistEpisode.episodeUuid
        missingEpisode.uploadStatus = UploadStatus.missing.rawValue
        missingEpisode.imageColor = 1

        return missingEpisode
    }

    func upNextTotalDuration(includePlayingEpisode: Bool) -> TimeInterval {
        let episodes = allEpisodes(includeNowPlaying: includePlayingEpisode)

        return episodes.map { $0.duration - $0.playedUpTo }.reduce(0, +)
    }

    // MARK: - Persistence

    func loadPersistedQueue() {
        cacheTopEpisode()
    }

    // MARK: - Private Helpers

    func updateUpNextInfo() {
        #if !os(watchOS)
            WidgetHelper.shared.updateSharedUpNext()
        #endif
    }

    private func checkAllForAutoDownload() {
        if !Settings.downloadUpNextEpisodes { return }

        DispatchQueue.global().async { [weak self] in
            guard let self else { return }
            let episodes = self.allEpisodes(includeNowPlaying: true)
            for episode in episodes {
                self.autoDownloadIfRequired(episode: episode)
            }
        }
    }

    private func autoDownloadIfRequired(episode: BaseEpisode) {
        // HLS is streamed directly and never cached, so downloading it in parallel would just
        // interrupt the stream once the download completes. Skip it. See DownloadManager.downloadParallelToStream.
        if EpisodeManager.hasHLSStream(episode) { return }

        if !Settings.downloadUpNextEpisodes || episode.queued() || episode.downloaded(pathFinder: DownloadManager.shared) { return }

        if Settings.autoDownloadMobileDataAllowed() || NetworkUtils.shared.isConnectedToUnexpensiveConnection() {
            DownloadManager.shared.addToQueue(episodeUuid: episode.uuid, autoDownloadStatus: .autoDownloaded)
        } else {
            DownloadManager.shared.queueForLaterDownload(episodeUuid: episode.uuid, fireNotification: true, autoDownloadStatus: .autoDownloaded)
        }
    }

    private func cacheTopEpisode() {
        topEpisode = episodeAt(index: -1)
    }

    private func refreshAppFiring(notificationName: Notification.Name?, notificationObject: Any? = nil, notificationUserInfo: [AnyHashable: Any]? = nil) {
        refreshList(checkForAutoDownload: true)

        if let name = notificationName {
            NotificationCenter.postOnMainThread(notification: name, object: notificationObject, userInfo: notificationUserInfo)
        }
    }
}
