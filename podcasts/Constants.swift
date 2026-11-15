import Foundation
import PocketCastsUtils
import UIKit

struct Constants {
    enum Notifications {
        static let upNextEpisodeAdded = NSNotification.Name(rawValue: "SJUpNextEpisodeAdded")
        /// `userInfo` key on `upNextEpisodeAdded` — a `Bool` that's `true` when
        /// the episode was added to the top of the queue (Play Next) rather than
        /// the bottom (Play Last). Drives the add-animation badge.
        static let upNextEpisodeAddedToTopKey = "PCUpNextAddedToTop"
        static let upNextEpisodeRemoved = NSNotification.Name(rawValue: "SJUpNextEpisodeRemoved")
        static let upNextQueueChanged = NSNotification.Name(rawValue: "SJUpNextChanged")
        static let upNextShuffleToggle = NSNotification.Name(rawValue: "SJUpNextShuffleToggle")
        static let playbackStarted = NSNotification.Name(rawValue: "SJPlaybackStart")
        static let playbackStarting = NSNotification.Name(rawValue: "SJPlaybackStarting")
        static let playbackPaused = NSNotification.Name(rawValue: "SJPlaybackPaused")
        static let playbackProgress = NSNotification.Name(rawValue: "SJPlaybackProg")
        static let playbackTrackChanged = NSNotification.Name(rawValue: "SJTrackChanged")
        static let podcastChaptersDidUpdate = NSNotification.Name(rawValue: "SJChaptersChanged")
        static let podcastChapterChanged = NSNotification.Name(rawValue: "SJChapterChanged")
        static let chapterSelectionChanged = NSNotification.Name(rawValue: "SJChapterSelectionChanged")
        static let playbackEnded = NSNotification.Name(rawValue: "SJPlaybackEnd")
        static let playbackFailed = NSNotification.Name(rawValue: "playbackFailed")
        static let playbackPositionSaved = NSNotification.Name(rawValue: "SJPlayPosSaved")
        static let viewWillTransitionToSize = NSNotification.Name(rawValue: "SJViewSizeChange")
        static let googleCastStatusChanged = NSNotification.Name(rawValue: "SJGCStatusChanged")
        static let googleCastMultiZoneStatusChanged = NSNotification.Name(rawValue: "SJGCMultiStatusChanged")
        static let downloadProgress = NSNotification.Name(rawValue: "SJDwnProg")
        static let podcastImageReCacheRequired = NSNotification.Name(rawValue: "PCPodcastImageReCacheRequired")

        static let skipTimesChanged = NSNotification.Name(rawValue: "SJSkipTimesChanged")
        static let episodeDownloaded = NSNotification.Name(rawValue: "SJEpisodeDownloaded")
        static let miniPlayerDidDisappear = NSNotification.Name(rawValue: "SJMiniPlayerDisappeared")
        static let miniPlayerDidAppear = NSNotification.Name(rawValue: "SJMiniPlayerAppeared")
        static let playlistChanged = NSNotification.Name(rawValue: "FilterChanged")
        static let statusBarHeightChanged = NSNotification.Name(rawValue: "SJBarHeightChanged")
        static let podcastSearchRequest = NSNotification.Name(rawValue: "PodcastSearchRequest")
        static let themeChanged = NSNotification.Name(rawValue: "ThemeChanged")
        static let systemThemeMayHaveChanged = NSNotification.Name(rawValue: "SystemThemeChanged")
        static let followSystemThemeTurnedOn = NSNotification.Name(rawValue: "FollowSystemThemeTurnedOn")
        static let playbackEffectsChanged = NSNotification.Name(rawValue: "SJEffectsChanged")
        static let extraMediaSessionActionsChanged = NSNotification.Name(rawValue: "SJMediaSessionActionsChanged")
        static let remoteCommandSettingsChanged = NSNotification.Name(rawValue: "SJRemoteCommandSettingsChanged")
        static let currentlyPlayingEpisodeUpdated = NSNotification.Name(rawValue: "SJCurrentlyPlayingEpisodeUpdated")
        static let sleepTimerChanged = NSNotification.Name(rawValue: "SJSleepTimerChanged")
        static let videoPlaybackEngineSwitched = NSNotification.Name(rawValue: "SJVideoPlaybackEngineSwitched")
        /// Posted when the user toggles the audio/video shelf action. Distinct from
        /// `videoPlaybackEngineSwitched` (runtime video detection) so it doesn't trigger auto-open behaviour.
        static let videoRenderingToggled = NSNotification.Name(rawValue: "SJVideoRenderingToggled")

        // episode notifications
        static let episodePlayStatusChanged = NSNotification.Name(rawValue: "SJEpPlayStatusChanged")
        static let episodeArchiveStatusChanged = NSNotification.Name(rawValue: "SJEpArchiveStatusChanged")
        static let episodeDurationChanged = NSNotification.Name(rawValue: "SJEpDurationChanged")
        static let episodeStarredChanged = NSNotification.Name(rawValue: "SJEpisodeStarredChanged")
        static let episodeDownloadStatusChanged = NSNotification.Name(rawValue: "SJEpisodeDownloadChanged")
        static let manyEpisodesChanged = NSNotification.Name(rawValue: "SJManyEpisodesChanged")
        static let episodeTranscriptAvailabilityChanged = NSNotification.Name(rawValue: "SJEpisodeTranscriptAvailabilityChanged")
        static let listeningHistoryChanged = NSNotification.Name(rawValue: "SJListeningHistoryChanged")

        // podcast notifications
        static let podcastUpdated = NSNotification.Name(rawValue: "SJPodcastUpdated")
        static let podcastAdded = NSNotification.Name(rawValue: "SJPodcastAdded")
        static let podcastDeleted = NSNotification.Name(rawValue: "SJPodDeleted")

        // user episode notifications
        static let userEpisodeDeleted = NSNotification.Name(rawValue: "SJUserEpisodeDeleted")
        static let userEpisodeUpdated = NSNotification.Name(rawValue: "SJUserEpisodeUpdated")

        // text editing
        static let textEditingDidStart = NSNotification.Name(rawValue: "SJTextEditingStarted")
        static let textEditingDidEnd = NSNotification.Name(rawValue: "SJTextEditingEnded")

        // shelf icons
        static let playerActionsUpdated = NSNotification.Name(rawValue: "SJPlayerActionsUpdated")

        // tabs
        static let tappedOnSelectedTab = NSNotification.Name(rawValue: "SJTappedOnSelectedTab")
        static let searchRequested = NSNotification.Name(rawValue: "SJTriggerSearch")

        // modal popups

        static let opmlImportCompleted = NSNotification.Name(rawValue: "SJOpmlImportCompleted")
        static let opmlImportFailed = NSNotification.Name(rawValue: "SJOpmlImportFailed")

        // watch

        // folders
        /// This is triggered many times whenever a folder is changed
        static let folderChanged = NSNotification.Name(rawValue: "SJFolderChanged")
        static let folderDeleted = NSNotification.Name(rawValue: "SJFolderDeleted")
        /// This is triggered just once after a folder finishes editing
        static let folderEdited = NSNotification.Name(rawValue: "SJFolderEdited")

        // End of Year
        static let profileSeen = NSNotification.Name(rawValue: "profileSeen")
    }

    enum UserDefaults {
        static let globalRemoveSilence = "GlobalRemSilenceSetting"
        static let globalVolumeBoost = "GlobalVolBoostSetting"
        static let globalPlaybackSpeed = "SJGlobalSpeedSetting"
        static let episodeFinishedAction = "SJPodcastFinishedAction"

        static let keepScreenOnWhilePlaying = "SJKeepScreenOnWhenPlaying"
        static let openPlayerAutomatically = "SJOpenPlayerAutomatically"
        static let intelligentPlaybackResumption = "SJIntelligentPlaybackResumption"
        static let hideImagesInShowNotes = "HideImagesInShowNotes"
        static let loadEmbeddedImages = "SJLoadEmbeddedArt"
        static let appBadge = "SJEppBadgeShows"
        static let pushEnabled = "PushEnabled"
        static let openLinksInExternalBrowser = "SJOpenLinksInExternalBrowser"

        static let appBadgeFilterUuid = "SJEppBadgeFilterId"
        static let lastAppCloseDate = "SJLastAppCloseDate"
        static let lastPlayEvent = "SJLastPlayEvent"
        static let cleanupUnplayed = "CleanupUnplayed"
        static let cleanupInProgress = "CleanupInProgress"
        static let cleanupPlayed = "CleanupPlayed"

        static let cleanupStarred = "CleanupStarred"
        static let lastFilterShown = "SJLastFilter"
        static let lastTabOpened = "SJLastTabOpened"
        static let lastImageRefreshTime = "SJLastImageRefreshDate"
        static let requestedPodcastImageSizes = "RequestedPodcastImageSizes"

        static let lastPickerSort = "PCLastPickerSort"

        static let shouldFollowSystemThemeKey = "FollowSystemTheme"
        static let themeKey = "theme"

        static let lastRunVersion = "lastRunVersion"

        static let showBadgeForEndOfYear = "showBadgeFor%dEndOfYear"
        static let modalHasBeenShown = "modal%dHasBeenShown"
        static let shouldShowInitialOnboardingFlow = "shouldShowInitialOnboardingFlow"

        static let autoplay = "autoplay"

        static let autoRestartSleepTimer = "autoRestartSleepTimer"
        static let shakeToRestartSleepTimer = "shakeToRestartSleepTimer"

        static let searchHistoryEntries = "SearchHistoryEntries"

        static let sleepTimerFinishedDate = "sleepTimerFinishedDate"
        static let sleepTimerSetting = "sleepTimerSetting"

        static let isLockScreenScrubbingDisabled = "IsLockScreenScrubbingDisabled"

        static let shouldShowRecentlyPlayedSortingTip = "ShouldShowRecentlyPlayedSortingTip"

        static let shouldShowUpNextSortDurationTip = "ShouldShowUpNextSortDurationTip"

        static let newFilterTip = "NewFilterTip"
        static let newFilterTipCreationView = "NewFilterTipCreationView"
        static let playlistDragAndDropTip = "PlaylistDragAndDropTip"
        static let playlistsOnboarding = "NewPlaylistsOnboarding"
        static let firstTimePlaylistCreated = "FirstTimePlaylistCreated"
        static let saveCurrentUpNextQueueIntoPlaylist = "SaveCurrentUpNextQueueIntoPlaylist"
        static let lastNetworkDataUsageCleanupDate = "lastNetworkDataUsageCleanupDate"

        enum headphones {
            static let previousAction = SettingValue("headphones.previousAction",
                                                      defaultValue: HeadphoneControlAction.skipBack)

            static let nextAction = SettingValue("headphones.nextAction",
                                                      defaultValue: HeadphoneControlAction.skipForward)
        }

        enum bookmarks {
            static let creationSound = SettingValue("bookmarks.creationSound", defaultValue: true)

            static let playerSort = SettingValue("bookmarks.playerSort", defaultValue: BookmarkSortOption.newestToOldest)
            static let podcastSort = SettingValue("bookmarks.podcastSort", defaultValue: BookmarkSortOption.newestToOldest)
            static let episodeSort = SettingValue("bookmarks.episodeSort", defaultValue: BookmarkSortOption.newestToOldest)
            static let profileSort = SettingValue("bookmarks.profileSort", defaultValue: BookmarkSortOption.newestToOldest)

            static let showPlayerTip = "bookmarks.showPlayerTip"
        }

        enum appearance {
            static let darkUpNextTheme = SettingValue("appearance.darkUpNextTheme", defaultValue: true)
            static var tabBarMinimizingEnabled: SettingValue<Bool> {
                SettingValue("appearance.tabBarMinimizingEnabled", defaultValue: !FeatureFlag.minimizeTabsOptIn.enabled)
            }
        }

        enum manageDownloads {
            static let lastCheckDate = "manageDownloadsLastCheckDate"
        }

        enum podcastFeedReload {
            static let showTip = "podcastFeedReload.showtip"
        }

        enum podcastViewChanges {
            static let showTip = "podcastViewChanges.showtip"
        }

        enum notifications {
            static let newEpisodes = "notifications.newEpisodes"
            static let dailyReminders = "notifications.dailyReminders"
            static let newFeaturesAndTips = "notifications.newFeaturesAndTips"
            static let triggerDates = "notifications.triggerDates"
        }

        static let voiceBoostNEnabled = "VoiceBoostNEnabled"
    }

    enum Values {
        static let miniPlayerOffset = 80 as CGFloat
        static let extraShowNotesVerticalSpacing: CGFloat = 60
        static let defaultPlaylistDownloadLimit = 10 as Int32

        static let minTimeBetweenPodcastImageUpdates = 4.weeks

        static let maxWidthForPopups: CGFloat = 500
        static let tableSectionHeaderHeight: CGFloat = 38
        static let tableRowHeaderHeight: CGFloat = 64

        static let refreshTaskId = "au.com.shiftyjelly.podcasts.Refresh"

        static let bookmarkMaxTitleLength = 100
    }

    enum Limits {
        static let minTimeBetweenRemoteSkips: TimeInterval = 0.2
        static let maxDownloadConnectionsPerHost = 2

        static let minSleepTime = 5.minutes
        static let maxSleepTime = 5.hours

        #if !os(watchOS)
            static let maxListItemsToSendToWatch = 50
            static let maxFilterItems = 1000
            static let maxCarplayItems = 100
            static let maxBulkDownloads = 100
            static let maxShelfActions = 4
        #endif
    }

    enum Animation {
        static let defaultAnimationTime = 0.3 as TimeInterval
        static let multiSelectStatusDelayTime = 0.8 as TimeInterval

        static let playerTabSwitch: TimeInterval = 0.2
    }

    #if !os(watchOS)
        enum SiriActions {
            static let resumeId = "Resume ID"
            static let playPodcastId = "Play podcast ID"
            static let playSuggestedId = "Play suggested ID"
            static let playUpNextId = "play up next ID"
            static let playFilterId = "Play filter ID"
            static let playAllFilterId = "Play all filter ID"
            static let pauseId = "Pause ID"
            static let nextChapterId = "Next Chapter ID"
            static let previousChapterId = "Previous Chapter ID"
            static let markAsPlayedId = "Mark As Played ID"
        }
    #endif

    enum Audio {
        static let defaultFrameSize = 1152
    }

    enum ConfigDefaults {
        static let podcastSearchDebounceMsDefault: Double = 800

        static let episodeSearchDebounceMsDefault: Double = 800

        static let addMissingEpisodesDefault: Bool = true
    }

    static let defaultDebounceTime: TimeInterval = 0.5

    /// The `SettingValue` provides a way to:
    ///     - Define a UserDefaults setting
    ///     - Specify the default value to be used if it's not set
    ///     - Retrieve and save the value to the user defaults
    /// Example:
    /// let helloWorld = SettingValue("hello", defaultValue: "world")
    /// print(helloWorld.value()) -> "world" // Default value is used
    /// helloWorld.save("hello world")
    /// print(helloWorld.value()) -> "hello world" // Custom value is used
    ///
    /// This uses Generics and the `defaultValue` to define the value type that should be set and returned.
    /// If you want to provide a nullable value you can:
    ///
    /// Specify an optional and a default value by wrapping the value in an `Optional`
    ///
    ///     SettingValue("nullable", defaultValue: Optional("HelloWorld"))
    ///
    /// Specify a type and a default value of nil by using `.none`
    ///
    ///     SettingValue("nullable", defaultValue: String?.none)
    ///
    struct SettingValue<Value> {
        let key: String
        let defaultValue: Value
        let defaults: Foundation.UserDefaults

        init(_ key: String, defaultValue: Value, defaults: Foundation.UserDefaults = .standard) {
            self.key = key
            self.defaultValue = defaultValue
            self.defaults = defaults
        }

        /// Retrieve the stored value from the UserDefaults or the `defaultValue` if there isn't a stored value
        var value: Value {
            guard let decodableType = Value.self as? JSONDecodable.Type else {
                return defaults.object(forKey: key) as? Value ?? defaultValue
            }

            return (try? defaults.jsonObject(decodableType.self, forKey: key) as? Value) ?? defaultValue
        }

        /// Saves the value to the UserDefaults. Passing nil to this will delete the key
        func save(_ value: Value) {
            guard let decodableType = value as? JSONEncodable else {
                defaults.set(value, forKey: key)
                return
            }

            defaults.setJSONObject(decodableType, forKey: key)
        }
    }
}

// MARK: - HeadphoneControlAction

/// Describes how the headphone/bluetooth skip next/back button actions should perform in the app
enum HeadphoneControlAction: JSONCodable {
    /// Skip back X seconds in the episode, where X is the Skip Back seconds settings value
    case skipBack

    /// Skip forward X seconds in the episode, where X is the Skip Forward seconds settings value
    case skipForward

    /// If the episode has chapters, then skip to the previous chapter, if not default to .skipBack behavior
    case previousChapter

    /// If the episode has chapters, then skip to the next chapter, if not default to .skipForward behavior
    case nextChapter

    /// Create a new bookmark for the currently playing episode
    case addBookmark
}

// MARK: - Bookmark Sorting

enum BookmarkSortOption: JSONCodable {
    case newestToOldest, oldestToNewest, timestamp, episode, podcastAndEpisode
}
