import Foundation

protocol TranscriptPlaybackManaging {
    var episodeUUID: String? { get }
    var podcastUUID: String? { get }
    var isPlayingEpisode: Bool { get }
}

extension PlaybackManager: TranscriptPlaybackManaging {
    var episodeUUID: String? {
        currentEpisode?.uuid
    }

    var podcastUUID: String? {
        currentPodcast?.uuid
    }

    var isPlayingEpisode: Bool {
        guard let episodeUUID else { return false }
        return isActivelyPlaying(episodeUuid: episodeUUID)
    }
}

struct TranscriptEpisodeInfoProvider: TranscriptPlaybackManaging {
    private let _episodeUUID: String

    var episodeUUID: String? { _episodeUUID }
    let podcastUUID: String?

    init(episodeUUID: String, podcastUUID: String) {
        self._episodeUUID = episodeUUID
        self.podcastUUID = podcastUUID
    }

    var isPlayingEpisode: Bool {
        PlaybackManager.shared.isActivelyPlaying(episodeUuid: _episodeUUID)
    }
}
