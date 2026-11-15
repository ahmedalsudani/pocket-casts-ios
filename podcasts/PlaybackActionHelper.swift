import Foundation
import PocketCastsDataModel
import PocketCastsServer
import PocketCastsUtils

@MainActor
enum PlaybackActionHelper {
    static func play(episode: BaseEpisode, playlistUuid: String? = nil, podcastUuid: String? = nil, playlist: AutoplayHelper.Playlist? = nil) {
        HapticsHelper.triggerPlayPauseHaptic()

        AutoplayHelper.shared.playedFrom(playlist: playlist)

        if GoogleCastManager.shared.connectedOrConnectingToDevice() {
            PlaybackManager.shared.load(episode: episode, autoPlay: true, overrideUpNext: false)
            return
        }

        if !episode.downloaded(pathFinder: DownloadManager.shared) {
            NetworkUtils.shared.streamEpisodeRequested({
                performPlay(episode: episode, playlistUuid: playlistUuid, podcastUuid: podcastUuid)
            }, disallowed: nil)
        } else {
            performPlay(episode: episode, playlistUuid: playlistUuid, podcastUuid: podcastUuid)
        }
    }

    static func pause() {
        HapticsHelper.triggerPlayPauseHaptic()
        PlaybackManager.shared.pause()
    }

    static func playPause() {
        HapticsHelper.triggerPlayPauseHaptic()
        PlaybackManager.shared.playPause()
    }

    static func download(episodeUuid: String) {
        NetworkUtils.shared.downloadEpisodeRequested(autoDownloadStatus: .notSpecified, { later in
            if later {
                DownloadManager.shared.queueForLaterDownload(episodeUuid: episodeUuid, fireNotification: true, autoDownloadStatus: .notSpecified)
            } else {
                DownloadManager.shared.addToQueue(episodeUuid: episodeUuid)
            }
        }, disallowed: nil)
    }

    static func stopDownload(episodeUuid: String) {
        DownloadManager.shared.removeFromQueue(episodeUuid: episodeUuid, fireNotification: true, userInitiated: true)
    }

    static func overrideWaitingForWifi(episodeUuid: String, autoDownloadStatus: AutoDownloadStatus) {
        NetworkUtils.shared.downloadEpisodeRequested(autoDownloadStatus: autoDownloadStatus, { later in
            if later {
                DownloadManager.shared.queueForLaterDownload(episodeUuid: episodeUuid, fireNotification: true, autoDownloadStatus: autoDownloadStatus)
            } else {
                DownloadManager.shared.addToQueue(episodeUuid: episodeUuid)
            }
        }, disallowed: nil)
    }

    private static func performPlay(episode: BaseEpisode, playlistUuid: String? = nil, podcastUuid: String? = nil) {
        if PlaybackManager.shared.isCurrentEpisode(uuid: episode.uuid) {
            PlaybackManager.shared.play()
        } else {
            if episode.archived, let episode = episode as? Episode {
                DataManager.shared.saveEpisode(archived: false, episode: episode, updateSyncFlag: false)
            }

            if episode is Episode { // only record play stats for Episodes, not UserEpisodes
            }

            PlaybackManager.shared.load(episode: episode, autoPlay: true, overrideUpNext: false)
        }
        if let playlistUuid {
            SiriShortcutsManager.shared.donatePlaylistPlayed(playlistUuid: playlistUuid)
        } else if let podcastUuid {
            SiriShortcutsManager.shared.donatePodcastPlayed(podcastUuid: podcastUuid)
        }
    }
}
