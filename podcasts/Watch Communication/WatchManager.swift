import Foundation
import PocketCastsDataModel
import PocketCastsServer
import PocketCastsUtils
import UIKit
import WatchConnectivity

class WatchManager: NSObject, WCSessionDelegate {
    static let shared = WatchManager()

    let logTaskManager = LogTaskManager()
    let logCache = LogCache()

    // Serial queue for WCSession operations to ensure thread safety
    private let sessionQueue = DispatchQueue(label: "com.pocketcasts.watchmanager.session", qos: .userInitiated)
    private var isSettingUp = false

    var isWatchAppInstalled: Bool {
        return WCSession.isSupported() && WCSession.default.isWatchAppInstalled
    }

    func setup() {
        guard WCSession.isSupported() else { return }

        sessionQueue.async { [weak self] in
            guard let self else { return }

            // Prevent multiple setup calls
            guard !self.isSettingUp else { return }
            self.isSettingUp = true

            let session = WCSession.default

            // Only set delegate and activate if not already active
            if session.delegate == nil || session.activationState != .activated {
                session.delegate = self
                session.activate()
            }

            self.isSettingUp = false
        }

        NotificationCenter.default.addObserver(self, selector: #selector(updateWatchData), name: Constants.Notifications.playlistChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(podcastsDidRefresh), name: ServerNotifications.podcastsRefreshed, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(podcastsDidRefresh), name: Constants.Notifications.opmlImportCompleted, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(upNextChanged), name: Constants.Notifications.upNextQueueChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(upNextChanged), name: Constants.Notifications.upNextEpisodeAdded, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(upNextChanged), name: Constants.Notifications.upNextEpisodeRemoved, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(playbackStateChanged), name: Constants.Notifications.playbackStarted, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(playbackStateChanged), name: Constants.Notifications.playbackPaused, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(playbackStateChanged), name: Constants.Notifications.playbackEnded, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(playbackStateChanged), name: Constants.Notifications.playbackPositionSaved, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(playbackStateChanged), name: Constants.Notifications.playbackEffectsChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(episodeStarredChanged(_:)), name: Constants.Notifications.episodeStarredChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(playbackStateChanged), name: Constants.Notifications.podcastChapterChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(playbackStateChanged), name: Constants.Notifications.podcastChaptersDidUpdate, object: nil)

        Task {
            let log = WatchManager.shared.readLogFile()
            await logCache.setCachedLog(log)
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        updateWatchData()
    }

    func sessionDidBecomeInactive(_ session: WCSession) {
        // we don't need to do anything here
    }

    func sessionDidDeactivate(_ session: WCSession) {
        // Begin the activation process for the new Apple Watch.
        sessionQueue.async {
            // Add a small delay to avoid immediate reactivation issues
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if WCSession.default.activationState != .activated {
                    WCSession.default.activate()
                }
            }
        }
    }

    func sessionWatchStateDidChange(_ session: WCSession) {
        updateWatchData()
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        guard FeatureFlag.watchTransferUserInfoApi.enabled else { return }
        if session.isReachable {
            updateWatchData()
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard let messageType = message[WatchConstants.Messages.messageType] as? String else {
            FileLog.shared.addMessage("WatchManager: Received message without messageType")
            return
        }

        handleWatchAction(messageType: messageType, payload: message)
    }

    // MARK: - Watch Action Handler

    /// Handles actions from the Watch, whether received via sendMessage or transferUserInfo.
    /// This unified handler ensures consistent behavior for both delivery mechanisms.
    private func handleWatchAction(messageType: String, payload: [String: Any]) {
        if WatchConstants.Messages.DataRequest.type == messageType {
            updateWatchData()
        } else if WatchConstants.Messages.PlayEpisodeRequest.type == messageType {
            if let episodeUuid = payload[WatchConstants.Messages.PlayEpisodeRequest.episodeUuid] as? String {
                let playlist = getPlaylist(from: payload)

                handlePlayRequest(episodeUuid: episodeUuid, playlist: playlist)
            }
        } else if WatchConstants.Messages.PlayPauseRequest.type == messageType {
            if PlaybackManager.shared.isPlaying {
                PlaybackManager.shared.pause()
            } else {
                PlaybackManager.shared.play()
            }
        } else if WatchConstants.Messages.SkipBackRequest.type == messageType {
            DispatchQueue.main.async {
                PlaybackManager.shared.skipBack()
            }
        } else if WatchConstants.Messages.SkipForwardRequest.type == messageType {
            PlaybackManager.shared.skipForward()
        } else if WatchConstants.Messages.StarRequest.type == messageType {
            if let starred = payload[WatchConstants.Messages.StarRequest.star] as? Bool, let uuid = payload[WatchConstants.Messages.StarRequest.episodeUuid] as? String {
                handleStarRequest(starred: starred, episodeUuid: uuid)
            }
        } else if WatchConstants.Messages.AddToUpNextRequest.type == messageType {
            if let toTop = payload[WatchConstants.Messages.AddToUpNextRequest.toTop] as? Bool, let uuid = payload[WatchConstants.Messages.AddToUpNextRequest.episodeUuid] as? String {
                handleAddToUpnext(episodeUuid: uuid, toTop: toTop)
            }
        } else if WatchConstants.Messages.RemoveFromUpNextRequest.type == messageType {
            if let uuid = payload[WatchConstants.Messages.RemoveFromUpNextRequest.episodeUuid] as? String {
                handleRemoveFromUpnext(episodeUuid: uuid)
            }
        } else if WatchConstants.Messages.MarkPlayedRequest.type == messageType {
            if let uuid = payload[WatchConstants.Messages.MarkPlayedRequest.episodeUuid] as? String {
                handleMarkPlayed(episodeUuid: uuid)
            }
        } else if WatchConstants.Messages.MarkUnplayedRequest.type == messageType {
            if let uuid = payload[WatchConstants.Messages.MarkUnplayedRequest.episodeUuid] as? String {
                handleMarkUnplayed(episodeUuid: uuid)
            }
        } else if WatchConstants.Messages.DownloadRequest.type == messageType {
            if let uuid = payload[WatchConstants.Messages.DownloadRequest.episodeUuid] as? String {
                handleDownload(episodeUuid: uuid)
            }
        } else if WatchConstants.Messages.StopDownloadRequest.type == messageType {
            if let uuid = payload[WatchConstants.Messages.StopDownloadRequest.episodeUuid] as? String {
                handleStopDownload(episodeUuid: uuid)
            }
        } else if WatchConstants.Messages.DeleteDownloadRequest.type == messageType {
            if let uuid = payload[WatchConstants.Messages.DeleteDownloadRequest.episodeUuid] as? String {
                handleDeleteDownload(episodeUuid: uuid)
            }
        } else if WatchConstants.Messages.ArchiveRequest.type == messageType {
            if let uuid = payload[WatchConstants.Messages.ArchiveRequest.episodeUuid] as? String {
                handleArchive(episodeUuid: uuid)
            }
        } else if WatchConstants.Messages.UnarchiveRequest.type == messageType {
            if let uuid = payload[WatchConstants.Messages.UnarchiveRequest.episodeUuid] as? String {
                handleUnarchive(episodeUuid: uuid)
            }
        } else if WatchConstants.Messages.ClearUpNextRequest.type == messageType {
            PlaybackManager.shared.queue.clearUpNextList()
        } else if WatchConstants.Messages.ChangeChapterRequest.type == messageType {
            if let nextChapter = payload[WatchConstants.Messages.ChangeChapterRequest.nextChapter] as? Bool {
                handleChangeChapter(next: nextChapter)
            }
        } else if WatchConstants.Messages.IncreaseSpeedRequest.type == messageType {
            let effects = PlaybackManager.shared.effects
            let desiredSpeed = effects.playbackSpeed + 0.1
            if desiredSpeed <= SharedConstants.PlaybackEffects.maximumPlaybackSpeed {
                effects.playbackSpeed = desiredSpeed
                PlaybackManager.shared.changeEffects(effects)
            }
        } else if WatchConstants.Messages.DecreaseSpeedRequest.type == messageType {
            let effects = PlaybackManager.shared.effects
            let desiredSpeed = effects.playbackSpeed - 0.1
            if desiredSpeed >= SharedConstants.PlaybackEffects.minimumPlaybackSpeed {
                effects.playbackSpeed = desiredSpeed
                PlaybackManager.shared.changeEffects(effects)
            }
        } else if WatchConstants.Messages.TrimSilenceRequest.type == messageType {
            guard let enabled = payload[WatchConstants.Messages.TrimSilenceRequest.enabled] as? Bool else { return }

            let effects = PlaybackManager.shared.effects
            effects.trimSilence = enabled ? .low : .off
            PlaybackManager.shared.changeEffects(effects)
        } else if WatchConstants.Messages.VolumeBoostRequest.type == messageType {
            guard let enabled = payload[WatchConstants.Messages.VolumeBoostRequest.enabled] as? Bool else { return }

            let effects = PlaybackManager.shared.effects
            effects.volumeBoost = enabled
            PlaybackManager.shared.changeEffects(effects)
        } else if WatchConstants.Messages.ChangeSpeedIntervalRequest.type == messageType {
            let effects = PlaybackManager.shared.effects
            effects.toggleDefinedSpeedInterval()

            PlaybackManager.shared.changeEffects(effects)
        }
    }

    func session(_ session: WCSession, didReceive file: WCSessionFile) {
        guard FeatureFlag.watchLogFileTransfer.enabled else { return }

        // Check if this is a log file transfer
        if file.metadata?[WatchConstants.Messages.messageType] as? String == WatchConstants.Messages.LogFileTransfer.type {
            handleLogFileTransfer(file: file)
        }
	}

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        // Handle actions transferred via transferUserInfo for guaranteed delivery
        // These are the same message types as didReceiveMessage but with guaranteed delivery
        guard FeatureFlag.watchTransferUserInfoApi.enabled else { return }
        guard let messageType = userInfo[WatchConstants.Messages.messageType] as? String else {
            FileLog.shared.addMessage("WatchManager: Received userInfo without messageType")
            return
        }

        handleWatchAction(messageType: messageType, payload: userInfo)
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        guard let messageType = message[WatchConstants.Messages.messageType] as? String else {
            FileLog.shared.addMessage("WatchManager: Received message without messageType (with reply handler)")
            replyHandler([String: Any]())
            return
        }

        if WatchConstants.Messages.FilterRequest.type == messageType {
            if let filterUuid = message[WatchConstants.Messages.FilterRequest.filterUuid] as? String {
                let response = handlePlaylistRequest(playlistUuid: filterUuid)
                replyHandler(response)
            }
        } else if WatchConstants.Messages.DownloadsRequest.type == messageType {
            let response = handleDownloadsRequest()
            replyHandler(response)
        } else if WatchConstants.Messages.UserEpisodeRequest.type == messageType {
            let response = handleUserEpisodeRequest()
            replyHandler(response)
        } else {
            // send blank response to messages we don't know about or for things we can't find info on
            FileLog.shared.addMessage("WatchManager: Unknown message type: \(messageType)")
            replyHandler([String: Any]())
        }
    }

    // MARK: Handler methods

    private func handleDownload(episodeUuid: String) {
        DownloadManager.shared.addToQueue(episodeUuid: episodeUuid, fireNotification: true, autoDownloadStatus: .notSpecified)
        sendStateToWatchInBackground()
    }

    private func handleStopDownload(episodeUuid: String) {
        DownloadManager.shared.removeFromQueue(episodeUuid: episodeUuid, fireNotification: true, userInitiated: true)
        sendStateToWatchInBackground()
    }

    private func handleDeleteDownload(episodeUuid: String) {
        guard let baseEpisode = DataManager.shared.findBaseEpisode(uuid: episodeUuid) else {
            FileLog.shared.addMessage("WatchManager: Could not find episode for delete download: \(episodeUuid)")
            return
        }

        if let userEpisode = baseEpisode as? UserEpisode {
            UserEpisodeManager.deleteFromDevice(userEpisode: userEpisode)
        } else if let episode = baseEpisode as? Episode {
            EpisodeManager.deleteDownloadedFiles(episode: episode, userInitated: true)
            NotificationCenter.postOnMainThread(notification: Constants.Notifications.episodeDownloadStatusChanged, object: episode.uuid)
        }
        sendStateToWatchInBackground()
    }

    private func handleArchive(episodeUuid: String) {
        guard let episode = DataManager.shared.findEpisode(uuid: episodeUuid) else { return }

        EpisodeManager.archiveEpisode(episode: episode, fireNotification: true)
        sendStateToWatchInBackground()
    }

    private func handleUnarchive(episodeUuid: String) {
        guard let episode = DataManager.shared.findEpisode(uuid: episodeUuid) else { return }

        EpisodeManager.unarchiveEpisode(episode: episode, fireNotification: true)
        sendStateToWatchInBackground()
    }

    private func handleChangeChapter(next: Bool) {
        if next {
            PlaybackManager.shared.skipToNextChapter()
        } else {
            PlaybackManager.shared.skipToPreviousChapter()
        }
    }

    private func handleLogFileTransfer(file: WCSessionFile) {
        do {
            let logContents = try String(contentsOf: file.fileURL, encoding: .utf8)
            Task {
                await logCache.setCachedLog(logContents)
                if FeatureFlag.refreshAndSaveWatchLogsOnSend.enabled {
                    saveLog(contents: logContents)
                }
            }
        } catch {
            FileLog.shared.addMessage("WatchManager: Failed to read transferred log file: \(error.localizedDescription)")
        }
    }

    private func handleMarkPlayed(episodeUuid: String) {
        guard let episode = DataManager.shared.findEpisode(uuid: episodeUuid) else { return }

        EpisodeManager.markAsPlayed(episode: episode, fireNotification: true)
        sendStateToWatchInBackground()
    }

    private func handleMarkUnplayed(episodeUuid: String) {
        guard let episode = DataManager.shared.findEpisode(uuid: episodeUuid) else { return }

        EpisodeManager.markAsUnplayed(episode: episode, fireNotification: true)
        sendStateToWatchInBackground()
    }

    private func handleAddToUpnext(episodeUuid: String, toTop: Bool) {
        guard let episode = DataManager.shared.findBaseEpisode(uuid: episodeUuid) else {
            FileLog.shared.addMessage("WatchManager: Episode not found for addToUpNext: \(episodeUuid)")
            return
        }

        // remove it first so that this can be used as a move to top/bottom as well
        PlaybackManager.shared.removeIfPlayingOrQueued(episode: episode, fireNotification: false, userInitiated: false)
        PlaybackManager.shared.addToUpNext(episode: episode, ignoringQueueLimit: true, toTop: toTop, userInitiated: true)
    }

    private func handleRemoveFromUpnext(episodeUuid: String) {
        guard let episode = DataManager.shared.findBaseEpisode(uuid: episodeUuid) else {
            FileLog.shared.addMessage("WatchManager: Episode not found for removeFromUpNext: \(episodeUuid)")
            return
        }

        PlaybackManager.shared.removeIfPlayingOrQueued(episode: episode, fireNotification: true, userInitiated: true)
    }

    private func handleStarRequest(starred: Bool, episodeUuid: String) {
        guard let episode = DataManager.shared.findEpisode(uuid: episodeUuid) else { return }

        EpisodeManager.setStarred(starred, episode: episode, updateSyncStatus: false)
    }

    private func handlePlayRequest(episodeUuid: String, playlist: AutoplayHelper.Playlist?) {
        guard let episode = DataManager.shared.findBaseEpisode(uuid: episodeUuid) else {
            FileLog.shared.addMessage("WatchManager: Could not find episode for play request: \(episodeUuid)")
            return
        }

        AutoplayHelper.shared.playedFrom(playlist: playlist)
        PlaybackManager.shared.load(episode: episode, autoPlay: true, overrideUpNext: false)
    }

    private func handlePlaylistRequest(playlistUuid: String) -> [String: Any] {
        guard let playlist = DataManager.shared.findPlaylist(uuid: playlistUuid) else { return [String: Any]() }

        let episodes: [Episode]
        let episodeQuery = PlaylistQueryBuilder.query(clause: .episode, for: playlist, episodeUuidToAdd: playlist.episodeUuidToAddToQueries(), limit: Int(playlist.maxAutoDownloadEpisodes()))
        episodes = DataManager.shared.findPlaylistEpisodesWhere(query: episodeQuery, arguments: nil)

        var convertedEpisodes = [[String: Any]]()
        for episode in episodes {
            if let convertedEpisode = convertForWatch(episode: episode) {
                convertedEpisodes.append(convertedEpisode)
            }
        }

        let response = [WatchConstants.Messages.FilterResponse.episodes: convertedEpisodes]

        return response
    }

    private func handleDownloadsRequest() -> [String: Any] {
        let episodes = DataManager.shared.findEpisodesWhere(customWhere: "episodeStatus == \(DownloadStatus.downloaded.rawValue) ORDER BY lastDownloadAttemptDate DESC LIMIT \(Constants.Limits.maxListItemsToSendToWatch)", arguments: nil)

        var convertedEpisodes = [[String: Any]]()
        for episode in episodes {
            if let convertedEpisode = convertForWatch(episode: episode) {
                convertedEpisodes.append(convertedEpisode)
            }
        }

        let response = [WatchConstants.Messages.DownloadsResponse.episodes: convertedEpisodes]

        return response
    }

    private func handleUserEpisodeRequest() -> [String: Any] {
        let sortBy = UploadedSort(rawValue: Settings.userEpisodeSortBy) ?? UploadedSort.newestToOldest
        let episodes = DataManager.shared.allUserEpisodes(sortedBy: sortBy, limit: Constants.Limits.maxListItemsToSendToWatch)
        var convertedEpisodes = [[String: Any]]()
        for episode in episodes {
            if let convertedEpisode = convertForWatch(episode: episode) {
                convertedEpisodes.append(convertedEpisode)
            }
        }

        let response = [WatchConstants.Messages.UserEpisodeResponse.episodes: convertedEpisodes]

        return response
    }

    // MARK: - App Notifications

    @objc private func updateWatchData() {
        sendStateToWatchInBackground()
    }

    @objc private func podcastsDidRefresh() {
        sendStateToWatchInBackground()
    }

    @objc private func upNextChanged() {
        sendStateToWatchInBackground()
    }

    @objc private func playbackStateChanged() {
        sendStateToWatchInBackground()
    }

    @objc private func episodeStarredChanged(_ notification: Notification) {
        guard let uuid = notification.object as? String, PlaybackManager.shared.queue.contains(episodeUuid: uuid) else { return }

        // currently the watch only needs to know if the starred status of something in Up Next changes
        sendStateToWatchInBackground()
    }

    private func sendStateToWatchInBackground() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.sendStateToWatch()
            if FeatureFlag.refreshAndSaveWatchLogsOnSend.enabled {
                WatchManager.shared.requestLogFile { _ in
                    // We do nothing here, the log file will be cached as a result of requesting
                }
            }
        }
    }

    /// The fallback Up Next limit to use when payload is too large.
    /// This is significantly smaller than the default to ensure the payload fits.
    private static let payloadTooLargeFallbackLimit = Constants.Limits.maxListItemsToSendToWatch

    private func sendStateToWatch() {
        sendStateToWatch(upNextLimit: nil)
    }

    private func sendStateToWatch(upNextLimit: Int?) {
        // This method should only be called from sessionQueue to ensure thread safety
        dispatchPrecondition(condition: .onQueue(sessionQueue))

        guard WCSession.isSupported() else { return }

        let session = WCSession.default

        guard session.activationState == .activated,
              session.isPaired,
              session.isWatchAppInstalled
        else {
            return
        }

        let timestamp = Date().timeIntervalSince1970

        var applicationDict = [String: Any]()
        applicationDict[WatchConstants.Messages.messageType] = WatchConstants.Messages.StateUpdate.type
        applicationDict[WatchConstants.Keys.messageVersion] = WatchConstants.Values.messageVersion
        applicationDict[WatchConstants.Keys.lastUpdateTime] = timestamp
        let featureFlags: [String: Bool] = FeatureFlag.allCases.reduce(into: [:]) { dict, feature in
            dict[feature.rawValue] = feature.enabled
        }
        applicationDict[WatchConstants.Keys.featureFlags] = featureFlags

        let upNextInfo = serializeUpNext(limit: upNextLimit)
        let upNextCount = upNextInfo.count

        applicationDict[WatchConstants.Keys.filters] = serializePlaylists()
        applicationDict[WatchConstants.Keys.nowPlayingInfo] = DispatchQueue.main.sync { serializeNowPlaying() }
        applicationDict[WatchConstants.Keys.upNextInfo] = upNextInfo
        if FeatureFlag.watchTransferUserInfoApi.enabled && session.isReachable {
            // When reachable, prefer sendMessage - messages are not queued like updateApplicationContext
            // See: https://linear.app/a8c/issue/PCIOS-504
            session.sendMessage(applicationDict, replyHandler: nil) { [weak self] error in
                guard let self else { return }
                FileLog.shared.addMessage("WatchManager sendStateToWatch via sendMessage failed \(error.localizedDescription)")
                if self.isPayloadTooLargeError(error) {
                    self.logPayloadTooLargeError(method: "sendMessage", upNextCount: upNextCount)
                    // Retry with reduced Up Next queue if we haven't already
                    if upNextLimit == nil {
                        FileLog.shared.addMessage("WatchManager: Retrying with reduced Up Next limit of \(Self.payloadTooLargeFallbackLimit)")
                        self.sessionQueue.async {
                            self.sendStateToWatch(upNextLimit: Self.payloadTooLargeFallbackLimit)
                        }
                    }
                }
            }
        } else {
            // When not reachable or feature flag disabled, use updateApplicationContext for eventual delivery
            do {
                try session.updateApplicationContext(applicationDict)
            } catch {
                FileLog.shared.addMessage("WatchManager sendStateToWatch via updateApplicationContext failed \(error.localizedDescription)")
                if isPayloadTooLargeError(error) {
                    logPayloadTooLargeError(method: "updateApplicationContext", upNextCount: upNextCount)
                    // Retry with reduced Up Next queue if we haven't already
                    if upNextLimit == nil {
                        FileLog.shared.addMessage("WatchManager: Retrying with reduced Up Next limit of \(Self.payloadTooLargeFallbackLimit)")
                        sendStateToWatch(upNextLimit: Self.payloadTooLargeFallbackLimit)
                    }
                }
            }
        }
    }

    /// Checks if a WatchConnectivity error is due to payload being too large.
    private func isPayloadTooLargeError(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == WCErrorDomain && nsError.code == WCError.Code.payloadTooLarge.rawValue
    }

    /// Logs a FileLog message if the WatchConnectivity error is due to payload being too large.
    /// This helps track when synced data exceeds WatchConnectivity's size limits.
    private func logPayloadTooLargeError(method: String, upNextCount: Int) {
        FileLog.shared.addMessage("WatchManager: Payload too large for \(method). Up Next count: \(upNextCount)")
    }

    // MARK: - Encoding

    private func serializeNowPlaying() -> [String: Any] {
        var nowPlayingInfo = [String: Any]()
        let playbackManager = PlaybackManager.shared
        if let playingEpisode = playbackManager.currentEpisode {
            nowPlayingInfo[WatchConstants.Keys.nowPlayingEpisode] = convertForWatch(episode: playingEpisode)
            nowPlayingInfo[WatchConstants.Keys.nowPlayingSubtitle] = playingEpisode.subTitle()
            nowPlayingInfo[WatchConstants.Keys.nowPlayingStatus] = playbackManager.isPlaying ? WatchConstants.PlayingStatus.playing : WatchConstants.PlayingStatus.paused
            if let playingEpisode = playingEpisode as? Episode, let podcast = playingEpisode.parentPodcast() {
                let color = ColorManager.darkThemeTint(for: podcast)
                nowPlayingInfo[WatchConstants.Keys.nowPlayingColor] = color.hexString()
            } else {
                nowPlayingInfo[WatchConstants.Keys.nowPlayingColor] = UIColor.white.hexString()
            }

            let hasChapters = playbackManager.chapterCount() > 0
            nowPlayingInfo[WatchConstants.Keys.nowPlayingHasChapters] = hasChapters
            let chapterTitle = playbackManager.currentChapters.title
            nowPlayingInfo[WatchConstants.Keys.nowPlayingChapterTitle] = chapterTitle

            let duration = playbackManager.duration
            let currentTime = playbackManager.currentTime
            nowPlayingInfo[WatchConstants.Keys.nowPlayingCurrentTime] = currentTime
            nowPlayingInfo[WatchConstants.Keys.nowPlayingDuration] = duration > 0 ? duration : 0

            nowPlayingInfo[WatchConstants.Keys.nowPlayingUpNextCount] = playbackManager.queue.upNextCount()

            let effects = playbackManager.effects
            nowPlayingInfo[WatchConstants.Keys.nowPlayingTrimSilence] = effects.trimSilence.isEnabled()
            nowPlayingInfo[WatchConstants.Keys.nowPlayingVolumeBoost] = effects.volumeBoost
            nowPlayingInfo[WatchConstants.Keys.nowPlayingSpeed] = effects.playbackSpeed
        }

        nowPlayingInfo[WatchConstants.Keys.nowPlayingSkipBackAmount] = Settings.skipBackTime
        nowPlayingInfo[WatchConstants.Keys.nowPlayingSkipForwardAmount] = Settings.skipForwardTime

        return nowPlayingInfo
    }

    private func serializeUpNext(limit: Int? = nil) -> [[String: Any]] {
        var upNextList = [[String: Any]]()

        let upNextEpisodes = PlaybackManager.shared.allEpisodesInQueue(includeNowPlaying: false)
        if upNextEpisodes.isEmpty { return upNextList }

        let episodesToSync: [BaseEpisode]
        if let limit {
            episodesToSync = Array(upNextEpisodes.prefix(limit))
        } else if FeatureFlag.unlimitedWatchUpNextSync.enabled {
            episodesToSync = upNextEpisodes
        } else {
            episodesToSync = Array(upNextEpisodes.prefix(Constants.Limits.maxListItemsToSendToWatch))
        }

        for episode in episodesToSync {
            if let convertedEpisode = convertForWatch(episode: episode) {
                upNextList.append(convertedEpisode)
            }
        }

        return upNextList
    }

    private func serializePlaylists() -> [[String: Any]] {
        let allPlaylists = DataManager.shared.allPlaylists(includeDeleted: false)
        var convertedPlaylists = [[String: Any]]()
        for playlist in allPlaylists {
            var convertedPlaylist = [String: Any]()
            convertedPlaylist[WatchConstants.Keys.filterTitle] = playlist.playlistName
            convertedPlaylist[WatchConstants.Keys.filterUuid] = playlist.uuid
            if let iconName = playlist.iconImageName() {
                convertedPlaylist[WatchConstants.Keys.filterIcon] = iconName
            }
            convertedPlaylists.append(convertedPlaylist)
        }
        return convertedPlaylists
    }

    // MARK: - Conversion

    private func convertForWatch(episode: BaseEpisode) -> [String: Any]? {
        var convertedEpisode = [String: Any]()

        if let episode = episode as? Episode {
            convertedEpisode[WatchConstants.Keys.episodeTypeKey] = "Episode"
            convertedEpisode[WatchConstants.Keys.episodeSerialisedKey] = episode.encodeToMap()
        } else if let episode = episode as? UserEpisode {
            convertedEpisode[WatchConstants.Keys.episodeTypeKey] = "UserEpisode"
            convertedEpisode[WatchConstants.Keys.episodeSerialisedKey] = episode.encodeToMap()
        }

        return convertedEpisode
    }

    private func getPlaylist(from message: [String: Any]) -> AutoplayHelper.Playlist? {
        if let playlistData = message[WatchConstants.Messages.PlayEpisodeRequest.playlist] as? Data {
            return try? JSONDecoder().decode(AutoplayHelper.Playlist.self, from: playlistData)
        }

        return nil
    }
}

// MARK: - Actor for Thread-Safe Task Management
actor LogTaskManager {
    private var currentTask: Task<Void, Never>?

    func setTask(_ task: Task<Void, Never>) {
        replaceTask(with: task)
    }

    func cancelCurrentTask() {
        replaceTask(with: nil)
    }

    func clearTask() {
        replaceTask(with: nil)
    }

    private func replaceTask(with newTask: Task<Void, Never>?) {
        currentTask?.cancel()
        currentTask = newTask
    }
}

// MARK: - Actor for Thread-Safe Log Caching
actor LogCache {
    private var cachedLog: String? = nil

    func getCachedLog() -> String? {
        return cachedLog
    }

    func setCachedLog(_ log: String?) {
        cachedLog = log
    }
}
