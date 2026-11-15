import Foundation

public enum FeatureFlag: String, CaseIterable {

    /// Whether End Of Year feature is enabled
    case endOfYear

    /// Enable the AVExportSession parallel download of any playing episode
    case streamAndCachePlayingEpisode

    /// Run a vacuum process on the database in order to optimize data fetch
    case runVacuumOnVersionUpdate

    /// Enable the End of Year 2024 recap
    case endOfYear2024

    /// Push two auto downloads on subscribe of a podcast
    case autoDownloadOnSubscribe

    /// Enable/Disable the podcast feed reload feature
    case podcastFeedUpdate

    /// Any time watch data is sent, we refresh the watch logs and save them to a file for viewing or exporting
    case refreshAndSaveWatchLogsOnSend

    /// Shows transcript excerpt in episode detail
    case episodeDetailTranscript

    /// Improves configuration for the streaming requet download session
    case streamingCustomSessionConfiguration

    /// Enabled the attributed text view in the Data Usage warning Sheet
    case useDescriptiveActionAttributedTextView

    /// Retry failed downloads and stream without the user agent
    case retryWithoutUserAgent

    /// Limit playback position changes when switching episodes
    case limitPlaybackPositionChanges

    /// Adds a sharing button to the transcript view
    case shareTranscripts

    /// Skips switching player to downloaded file if already playing from the same cached streamed file
    case doNotSwitchToDownloadedFile

    /// Enable the End of Year 2025 recap
    case endOfYear2025

    /// Enable the End of Year to use first story as loading screen
    case endOfYearLoadIsFirstStory

    /// Upgrades the Effects Player's AudioReadTask to a QOS level of "userInitiated" from "default"
    case effectsPlayerQOSUpgrade

    /// Uses the PlaylistMetadataLoader cache before running the query (the query will update when it's done)
    case playlistDataCacheBeforeQuery

    /// Use cellular-specific network APIs instead of expensive network APIs
    case useCellularNetworkApis

    /// Optimizes manual playlist queries with improved deduplication
    case optimizeManualPlaylistQueries

    /// Use a background queue for streaming callbacks
    case useBackgroundQueueForStreamingCallback

    /// Moves the shouldKeepPlaying after we check that the episode is over
    case checkFinishedTimeBeforeShouldKeepPlaying

    /// Activate audio session to enable multi-speaker selection in route picker
    case activateAudioSessionForRoutePicker

    /// Don't autoplay when route changes
    case dontAutoplayOnRouteChange

    /// Allow the release of the Media Exporter when is no longer being used by the player
    case releaseMediaExporterWhenNoLongerActive

    /// Enable VoiceBoostN with updated description copy (TestFlight only)
    case voiceBoostN

    /// Adds invalidation to the playlist cache on appearance when its been > 30 seconds
    case playlistCacheInvalidation

    /// Use WCSessionFileTransfer to send logs from watchOS to iPhone instead of sendMessage reply
    case watchLogFileTransfer

    /// Use transferUserInfo API for watch-to-phone actions and sendMessage for phone-to-watch state updates
    case watchTransferUserInfoApi

    /// Remove the 50-episode limit when syncing Up Next to Apple Watch
    case unlimitedWatchUpNextSync

    /// Ensure that tmp files are removed when no longer needed
    case cleanUpTmpFiles

    /// Display playback errors on player
    case displayErrorsOnPlayer

    /// Track network data usage per episode/connection type in the NetworkDataUsage table
    case trackNetworkDataUsage

    /// Show the listening activity heatmap on the Stats screen
    case statsHeatmap

    /// Show explicit content badges on podcasts
    case showExplicitBadges

    /// Enable the Up Next sort button
    case upNextSort

    /// Enable HLS streaming playback
    case hls

    /// Enable Smart Bookmarks
    case smartBookmarks

    /// Make the tab bar's minimize-on-scroll behavior opt-in: it's off unless the
    /// user turns it on in Appearance
    case minimizeTabsOptIn

    /// Introduce Smart Bookmarks with a tip in the player and a "New" badge on the Add Bookmark row.
    ///
    /// The promo runs for 8.19, 8.20 and 8.21 only. Remove this flag and `SmartBookmarksPromo` when 8.22 is cut.
    case smartBookmarksPromo

    /// Show a Live Activity on the Lock Screen and Dynamic Island while the sleep timer is running
    case sleepTimerLiveActivity

    /// Don't pause on a route change while a play request is activating the audio session
    case ignoreRouteChangeWhilePlayRequestPending

    /// Show the full screen player and its tabs side by side on large screens (iOS 27.1+),
    /// over a blurred artwork background
    case largeScreenNowPlaying

    /// Show the Played Podcasts option in the Podcasts tab, which hides podcasts with nothing left to listen to
    case hidePlayedPodcasts

    /// Update the podcast cache from the rows each write changes, instead of reloading every podcast after each write
    case reloadOnlySavedPodcast

    /// Save the episodes a podcast update finds missing in transactions of up to 100, instead of one by one
    case saveMissingEpisodesInOneTransaction

    /// Give a new episode the ID after the largest one in the table instead of a random ID
    case sequentialEpisodeIds

    /// Count smart playlists and pick their artwork without walking the episode table in index order, and load the Playlists tab's counts and artwork two queries at a time
    case efficientPlaylistQueries

    /// When a podcast is followed, send a HEAD request for its newest episode to update the episode's file type and size
    case newPodcastMetadataRequest

    public var enabled: Bool {
        if let overriddenValue = FeatureFlagOverrideStore().overriddenValue(for: self) {
            return overriddenValue
        }

        return `default`
    }

    public var `default`: Bool {
        switch self {
        case .endOfYear:
            false
        case .streamAndCachePlayingEpisode:
            true
        case .runVacuumOnVersionUpdate:
            false
        case .endOfYear2024:
            false
        case .autoDownloadOnSubscribe:
            true
        case .podcastFeedUpdate:
            true
        case .refreshAndSaveWatchLogsOnSend:
            true
        case .episodeDetailTranscript:
            true
        case .streamingCustomSessionConfiguration:
            true
        case .useDescriptiveActionAttributedTextView:
            true
        case .retryWithoutUserAgent:
            true
        case .limitPlaybackPositionChanges:
            true
        case .shareTranscripts:
            true
        case .doNotSwitchToDownloadedFile:
            true
        case .endOfYear2025:
            false
        case .endOfYearLoadIsFirstStory:
            true
        case .effectsPlayerQOSUpgrade:
            true
        case .playlistDataCacheBeforeQuery:
            true
        case .useCellularNetworkApis:
            true
        case .optimizeManualPlaylistQueries:
            true
        case .useBackgroundQueueForStreamingCallback:
            true
        case .checkFinishedTimeBeforeShouldKeepPlaying:
            true
        case .activateAudioSessionForRoutePicker:
            true
        case .dontAutoplayOnRouteChange:
            true
        case .releaseMediaExporterWhenNoLongerActive:
            true
        case .voiceBoostN:
            false
        case .playlistCacheInvalidation:
            true
        case .watchLogFileTransfer:
            true
        case .watchTransferUserInfoApi:
            true
        case .unlimitedWatchUpNextSync:
            true
        case .cleanUpTmpFiles:
            true
        case .displayErrorsOnPlayer:
            true
        case .trackNetworkDataUsage:
            true
        case .statsHeatmap:
            true
        case .showExplicitBadges:
            true
        case .upNextSort:
            true
        case .hls:
            true
        case .smartBookmarks:
            true
        case .minimizeTabsOptIn:
            true
        case .smartBookmarksPromo:
            true
        case .sleepTimerLiveActivity:
            true
        case .ignoreRouteChangeWhilePlayRequestPending:
            true
        case .largeScreenNowPlaying:
            true
        case .hidePlayedPodcasts:
            true
        case .reloadOnlySavedPodcast:
            true
        case .saveMissingEpisodesInOneTransaction:
            true
        case .sequentialEpisodeIds:
            true
        case .efficientPlaylistQueries:
            true
        case .newPodcastMetadataRequest:
            false
        }
    }
}

extension FeatureFlag: OverrideableFlag {
    public var description: String {
        rawValue
    }

    public var canOverride: Bool {
        true
    }
}
