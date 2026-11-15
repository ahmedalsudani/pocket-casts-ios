import PocketCastsDataModel
#if !os(watchOS)
#endif
import PocketCastsServer
import UIKit
import SwiftUI
import PocketCastsUtils

class Settings: NSObject {

#if !os(watchOS)
    static var debugPlaylistsLimit = Constants.Limits.maxFilterItems
#endif

    static var isLockScreenScrubbingDisabled: Bool {
        set {
            UserDefaults.standard.set(newValue, forKey: Constants.UserDefaults.isLockScreenScrubbingDisabled)
            NotificationCenter.default.post(name: Constants.Notifications.remoteCommandSettingsChanged, object: nil)
        }
        get {
            return UserDefaults.standard.bool(forKey: Constants.UserDefaults.isLockScreenScrubbingDisabled)
        }
    }

    static var openLinks: Bool {
        set {
            UserDefaults.standard.set(newValue, forKey: Constants.UserDefaults.openLinksInExternalBrowser)
        }
        get {
            UserDefaults.standard.bool(forKey: Constants.UserDefaults.openLinksInExternalBrowser)
        }
    }

    // MARK: - Library Type

    static let podcastLibraryGridTypeKey = "SJPodcastLibraryGridType"
    private static var cachedlibrarySortType: LibraryType?
    static var libraryType: LibraryType {
        get {
            if let type = cachedlibrarySortType {
                return type
            }

            let storedValue = UserDefaults.standard.integer(forKey: Settings.podcastLibraryGridTypeKey)
            if let type = LibraryType(oldValue: storedValue) {
                cachedlibrarySortType = type

                return type
            }

            return LibraryType.threeByThree // default value
        }
        set(type) {
            UserDefaults.standard.set(type.old.rawValue, forKey: Settings.podcastLibraryGridTypeKey)
            cachedlibrarySortType = type
        }
    }

    // MARK: - Podcast Badge

    static let badgeKey = "SJBadgeType"
    static var podcastBadgeType: BadgeType {
        get {
            let storedBadgeType = UserDefaults.standard.integer(forKey: Settings.badgeKey)

            if let type = BadgeType(rawValue: Int32(storedBadgeType)) {
                return type
            }

            return .off
        }
        set(badgeType) {
            UserDefaults.standard.set(badgeType.rawValue, forKey: Settings.badgeKey)
        }
    }

    // MARK: - Played Podcasts

    private static let hidePlayedPodcastsKey = "HidePlayedPodcasts"
    static var hidePlayedPodcasts: Bool {
        get {
            UserDefaults.standard.bool(forKey: Settings.hidePlayedPodcastsKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Settings.hidePlayedPodcastsKey)
        }
    }

    /// The podcasts to leave out of the Podcasts tab and folders, based on `hidePlayedPodcasts`.
    static func hiddenPodcastUuids() -> Set<String> {
        FeatureFlag.hidePlayedPodcasts.enabled && hidePlayedPodcasts ? DataManager.shared.playedPodcastUuids() : []
    }

    // MARK: - Up Next Auto Download

    private static let autoDownloadUpNext = "SJAutoDownloadUpNext"
    static var downloadUpNextEpisodes: Bool {
        get {
            UserDefaults.standard.bool(forKey: Settings.autoDownloadUpNext)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Settings.autoDownloadUpNext)
        }
    }

    // MARK: - Mobile Data

    static let allowCellularDownloadKey = "SJUserCellular"
    class func mobileDataAllowed() -> Bool {
        UserDefaults.standard.bool(forKey: Settings.allowCellularDownloadKey)
    }

    class func setMobileDataAllowed(_ allow: Bool, userInitiated: Bool = false) {
        UserDefaults.standard.set(allow, forKey: Settings.allowCellularDownloadKey)

        guard userInitiated else { return }
    }

    // MARK: - Auto Download Mobile Data

    private static let allowCellularAutoDownloadKey = "SJUserCellularAutoDownload"
    class func autoDownloadMobileDataAllowed() -> Bool {
        UserDefaults.standard.bool(forKey: Settings.allowCellularAutoDownloadKey)
    }

    class func setAutoDownloadMobileDataAllowed(_ allow: Bool, userInitiated: Bool = false) {
        UserDefaults.standard.set(allow, forKey: Settings.allowCellularAutoDownloadKey)

        guard userInitiated else { return }
    }

    // MARK: - Auto Download

    private static let autoDownloadEnabledKey = "AutoDownloadEnabled"
    class func autoDownloadEnabled() -> Bool {
        guard UserDefaults.standard.object(forKey: Settings.autoDownloadEnabledKey) != nil else {
            return FeatureFlag.autoDownloadOnSubscribe.enabled
        }
        return UserDefaults.standard.bool(forKey: Settings.autoDownloadEnabledKey)
    }

    class func setAutoDownloadEnabled(_ allow: Bool, userInitiated: Bool = false) {
        UserDefaults.standard.set(allow, forKey: Settings.autoDownloadEnabledKey)

        guard userInitiated else { return }
    }

    private static let autoDownloadOnFollowKey = "AutoDownloadOnFollow"
    class func autoDownloadOnFollow() -> Bool {
        guard UserDefaults.standard.object(forKey: Settings.autoDownloadOnFollowKey) != nil else {
            return false
        }
        return UserDefaults.standard.bool(forKey: Settings.autoDownloadOnFollowKey)
    }

    class func setAutoDownloadOnFollow(_ allow: Bool, userInitiated: Bool = false) {
        UserDefaults.standard.set(allow, forKey: Settings.autoDownloadOnFollowKey)

        guard userInitiated else { return }
    }

    private static let autoDownloadLimitKey = "AutoDownloadLimit"
    static var autoDownloadLimits: AutoDownloadLimit {
        get {
            AutoDownloadLimit(rawValue: UserDefaults.standard.integer(forKey: Settings.autoDownloadLimitKey)) ?? .two
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: Settings.autoDownloadLimitKey)
        }
    }

    class func setShouldDeleteWhenPlayed(_ shouldDelete: Bool) {
        let finishedAction = shouldDelete ? PodcastFinishedAction.delete : PodcastFinishedAction.doNothing

        UserDefaults.standard.setValue(finishedAction.rawValue, forKey: Constants.UserDefaults.episodeFinishedAction)
    }

    // MARK: - Default Archive Hiding

    static let defaultArchiveBehaviour = "SJDefaultArchive"
    static var showArchivedDefault: Bool {
        get {
            UserDefaults.standard.bool(forKey: defaultArchiveBehaviour)
        }
        set(showArchived) {
            UserDefaults.standard.set(showArchived, forKey: defaultArchiveBehaviour)
        }
    }

    // MARK: - Primary Row Action

    static let primaryRowActionKey = "SJRowAction"
    private static var cachedPrimaryRowAction: PrimaryRowAction? // we cache this because it's used in lists
    static var primaryRowAction: PrimaryRowAction {
        get {
            if let action = cachedPrimaryRowAction { return action }
            let storedValue = UserDefaults.standard.integer(forKey: primaryRowActionKey)
            let action = PrimaryRowAction(rawValue: Int32(storedValue)) ?? .stream
            cachedPrimaryRowAction = action
            return action
        }
        set(action) {
            UserDefaults.standard.set(
                action.rawValue,
                forKey: primaryRowActionKey
            )
            cachedPrimaryRowAction = action
        }
    }

    // MARK: - Podcast Sort Order

    static var homeFolderSortOrder: LibrarySort {
        get {
            let sortInt = ServerSettings.homeGridSortOrder()
            if let librarySort = LibrarySort(oldValue: sortInt) {
                return librarySort
            }

            return .dateAddedNewestToOldest
        }
        set(order) {
            ServerSettings.setHomeGridSortOrder(order.old.rawValue)
        }
    }

    // MARK: - Podcast Grouping Default

    static let podcastGroupingDefaultKey = "SJDefaultPodcastGrouping"
    private static var cachedPodcastGrouping: PodcastGrouping?
    static var defaultPodcastGrouping: PodcastGrouping {
        get {
            if let grouping = cachedPodcastGrouping { return grouping }

            let storedValue = UserDefaults.standard.integer(forKey: podcastGroupingDefaultKey)
            let defaultGrouping = PodcastGrouping(rawValue: Int32(storedValue)) ?? .none
            cachedPodcastGrouping = defaultGrouping

            return defaultGrouping
        }
        set(grouping) {
            UserDefaults.standard.set(grouping.rawValue, forKey: podcastGroupingDefaultKey)
            cachedPodcastGrouping = grouping
        }
    }

    // MARK: - Primary Up Next Swipe Action

    static let primaryUpNextSwipeActionKey = "SJUpNextSwipe"
    private static var cachedPrimaryUpNextSwipeAction: PrimaryUpNextSwipeAction? // we cache this because it's used in lists
    static var primaryUpNextSwipeAction: PrimaryUpNextSwipeAction {
        get {
            if let action = cachedPrimaryUpNextSwipeAction { return action }

            let storedValue = UserDefaults.standard.integer(forKey: primaryUpNextSwipeActionKey)
            let primaryAction = PrimaryUpNextSwipeAction(rawValue: Int32(storedValue)) ?? .playNext
            cachedPrimaryUpNextSwipeAction = primaryAction

            return primaryAction
        }
        set(action) {
            UserDefaults.standard.set(action.rawValue, forKey: primaryUpNextSwipeActionKey)
            cachedPrimaryUpNextSwipeAction = action
        }
    }

    // MARK: - Play Up Next On Tap

    static let playUpNextOnTapKey = "SJPlayUpNextOnTap"
    static var playUpNextOnTap: Bool {
        get {
            UserDefaults.standard.bool(forKey: Settings.playUpNextOnTapKey)
        }
        set(isOn) {
            UserDefaults.standard.set(isOn, forKey: Settings.playUpNextOnTapKey)
        }
    }

    static let upNextShuffleKey = "SJUpNextShuffleKey"
    class func upNextShuffleToggle() {
        let isOn = upNextShuffleEnabled()
        UserDefaults.standard.set(!isOn, forKey: Settings.upNextShuffleKey)

        NotificationCenter.postOnMainThread(notification: Constants.Notifications.upNextShuffleToggle)
    }

    class func upNextShuffleEnabled() -> Bool {
        UserDefaults.standard.bool(forKey: Settings.upNextShuffleKey)
    }

    // MARK: - Auto Archiving

    static let autoArchivePlayedAfterKey = "AutoArchivePlayedAfer"
    class func autoArchivePlayedAfter() -> TimeInterval {
        UserDefaults.standard.double(forKey: Settings.autoArchivePlayedAfterKey)
    }

    class func setAutoArchivePlayedAfter(_ after: TimeInterval, userInitiated: Bool = false) {
        UserDefaults.standard.set(after, forKey: Settings.autoArchivePlayedAfterKey)

        guard userInitiated else { return }
    }

    static let autoArchiveInactiveAfterKey = "AutoArchiveInactiveAfer"
    class func autoArchiveInactiveAfter() -> TimeInterval {
        UserDefaults.standard.double(forKey: Settings.autoArchiveInactiveAfterKey)
    }

    class func setAutoArchiveInactiveAfter(_ after: TimeInterval, userInitiated: Bool = false) {
        UserDefaults.standard.set(after, forKey: Settings.autoArchiveInactiveAfterKey)

        guard userInitiated else { return }
    }

    static let archiveStarredEpisodesKey = "ArchiveStarredEpisodes"
    class func archiveStarredEpisodes() -> Bool {
        UserDefaults.standard.bool(forKey: Settings.archiveStarredEpisodesKey)
    }

    class func setArchiveStarredEpisodes(_ archive: Bool, userInitiated: Bool = false) {
        UserDefaults.standard.set(archive, forKey: Settings.archiveStarredEpisodesKey)

        guard userInitiated else { return }
    }

    // MARK: - App Info

    @objc class func appVersion() -> String {
        guard let infoDictionary = Bundle.main.infoDictionary, let shortVersion = infoDictionary["CFBundleShortVersionString"] as? String else {
            return "6.0" // this should never fail, but it's a nicer API to not return nil
        }

        return shortVersion
    }

    class func displayableVersion() -> String {
#if STAGING
        return L10n.appVersion(Settings.appVersion(), Settings.buildNumber()) + " - STAGING"
#else
        return L10n.appVersion(Settings.appVersion(), Settings.buildNumber())
#endif
    }

    class func buildNumber() -> String {
        guard let infoDictionary = Bundle.main.infoDictionary, let buildNumber = infoDictionary[kCFBundleVersionKey as String] as? String else {
            return "1" // this should never fail, but it's a nicer API to not return nil
        }

        return buildNumber
    }

    // MARK: - Sleep Time

    private static let customSleepTimeKey = "CustomSleepTime"
    static var customSleepTime: TimeInterval {
        get {
            let savedTime = UserDefaults.standard.double(forKey: Settings.customSleepTimeKey)
            if savedTime < Constants.Limits.minSleepTime { return Constants.Limits.minSleepTime }

            return savedTime
        }
        set {
            let adjustedTime = newValue < Constants.Limits.minSleepTime ? Constants.Limits.minSleepTime : newValue
            UserDefaults.standard.set(adjustedTime, forKey: Settings.customSleepTimeKey)
        }
    }

    static var sleepTimerNumberOfEpisodes: Int {
        get {
            UserDefaults.standard.object(forKey: "sleep_timer_custom_number_of_episodes") as? Int ?? 1
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "sleep_timer_custom_number_of_episodes")
        }
    }

    // MARK: - CarPlay/Lock Screen actions

    static let mediaSessionActionsKey = "MediaSessionActions"
    static var extraMediaSessionActionsEnabled: Bool {
        get {
            UserDefaults.standard.bool(forKey: Settings.mediaSessionActionsKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Settings.mediaSessionActionsKey)

            NotificationCenter.postOnMainThread(notification: Constants.Notifications.extraMediaSessionActionsChanged)
        }
    }

    // MARK: - Legacy Bluetooth Support

    static let legacyBtSupportKey = "LegacyBtSupport"
    static var legacyBluetoothModeEnabled: Bool {
        get {
            UserDefaults.standard.bool(forKey: Settings.legacyBtSupportKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Settings.legacyBtSupportKey)
        }
    }

    // MARK: - Publish Chapter Titles

    static let publishChapterTitlesKey = "PublishChapterTitles"
    static var publishChapterTitlesEnabled: Bool {
        get {
            if let isEnabled = UserDefaults.standard.value(forKey: Settings.publishChapterTitlesKey) as? Bool {
                return isEnabled
            }

            return true
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Settings.publishChapterTitlesKey)
        }
    }

    // MARK: - User Episode Settings

    public static let userEpisodeSortByKey = "UserEpisodeSortBy"
    static var userEpisodeSortBy: Int32 {
        get {
            Int32(UserDefaults.standard.integer(forKey: userEpisodeSortByKey))
        }
        set {
            UserDefaults.standard.set(newValue, forKey: userEpisodeSortByKey)
        }
    }

    static let userEpisodeAutoAddToUpNextKey = "UserEpisodeAutoAddToUpNext"
    static var userEpisodeAutoAddToUpNext: Bool {
        get {
            UserDefaults.standard.bool(forKey: userEpisodeAutoAddToUpNextKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: userEpisodeAutoAddToUpNextKey)
        }
    }

    static let userEpisodeRemoveFileAfterPlayingKey = "UserEpisodeRemoveFileAfterPlaying"
    static var userEpisodeRemoveFileAfterPlaying: Bool {
        get {
            UserDefaults.standard.bool(forKey: userEpisodeRemoveFileAfterPlayingKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: userEpisodeRemoveFileAfterPlayingKey)
        }
    }

    static var shouldFollowSystemTheme: Bool {
        get {
            UserDefaults.standard.bool(forKey: Constants.UserDefaults.shouldFollowSystemThemeKey)
        }
        set(value) {
            UserDefaults.standard.set(value, forKey: Constants.UserDefaults.shouldFollowSystemThemeKey)
        }
    }

    // MARK: Player Actions

    fileprivate static let playerActionsKey = "PlayerActions"
    class func playerActions() -> [PlayerAction] {
        let defaultActions = PlayerAction.defaultActions.filter { $0.isAvailable }

        let playerActions = UserDefaults.standard.playerActions ?? defaultActions

        return playerActions + defaultActions.filter { !playerActions.contains($0) }
    }

    class func updatePlayerActions(_ actions: [PlayerAction]) {
        let actionInts = actions.map(\.intValue)
        UserDefaults.standard.set(actionInts, forKey: Settings.playerActionsKey)

        NotificationCenter.postOnMainThread(notification: Constants.Notifications.playerActionsUpdated)
    }

    // MARK: Multi Select Gesture

    static let multiSelectGestureKey = "MultiSelectGestureEnabled"
    class func multiSelectGestureEnabled() -> Bool {
        UserDefaults.standard.bool(forKey: multiSelectGestureKey)
    }

    class func setMultiSelectGestureEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: multiSelectGestureKey)
    }

    // MARK: Multi Select Actions

    private static let multiSelectActionsKey = "MultiSelectActions"
    class func multiSelectActions() -> [MultiSelectAction] {
        let defaultActions: [MultiSelectAction] = [.playNext, .playLast, .removeFromUpNext, .addToPlaylist, .download, .archive, .share, .markAsPlayed, .star]
        guard let savedInts = UserDefaults.standard.object(forKey: Settings.multiSelectActionsKey) as? [Int32] else {
            return defaultActions
        }

        let actions = savedInts.compactMap { MultiSelectAction(rawValue: $0) }

        // Make sure new items are shown
        return actions + defaultActions.filter { !actions.contains($0) }
    }

    class func updateMultiSelectActions(_ actions: [MultiSelectAction]) {
        let actionInts = actions.map(\.rawValue)
        UserDefaults.standard.set(actionInts, forKey: Settings.multiSelectActionsKey)
    }

    private static let listeningHistoryMultiSelectActionsKey = "ListeningHistoryMultiSelectActions"
    class func listeningHistoryMultiSelectActions() -> [MultiSelectAction] {
        let defaultActions: [MultiSelectAction] = [.playNext, .playLast, .removeFromUpNext, .download, .archive, .share, .removeListeningHistory, .markAsPlayed, .star]
        guard let savedInts = UserDefaults.standard.object(forKey: Settings.listeningHistoryMultiSelectActionsKey) as? [Int32] else {
            return defaultActions
        }

        let actions = savedInts.compactMap { MultiSelectAction(rawValue: $0) }

        // Make sure new items are shown
        return actions + defaultActions.filter { !actions.contains($0) }
    }

    class func updateListeningHistoryMultiSelectActions(_ actions: [MultiSelectAction]) {
        let actionInts = actions.map(\.rawValue)
        UserDefaults.standard.set(actionInts, forKey: Settings.listeningHistoryMultiSelectActionsKey)
    }

    private static let filesMultiSelectActionsKey = "FilesMultiSelectActionsV2"
    class func fileMultiSelectActions() -> [MultiSelectAction] {
        guard let savedInts = UserDefaults.standard.object(forKey: Settings.filesMultiSelectActionsKey) as? [Int32] else {
            return [.playNext, .playLast, .download, .markAsPlayed, .delete]
        }

        let actions = savedInts.compactMap { MultiSelectAction(rawValue: $0) }

        return actions
    }

    class func updateFilesMultiSelectActions(_ actions: [MultiSelectAction]) {
        let actionInts = actions.map(\.rawValue)
        UserDefaults.standard.set(actionInts, forKey: Settings.filesMultiSelectActionsKey)
    }

    private static let upNextMultiSelectActionsKey = "UpNextMultiSelectActions"
    class func upNextMultiSelectActions() -> [MultiSelectAction] {
        let defaultActions: [MultiSelectAction] = [.moveToTop, .moveToBottom, .removeFromUpNext, .download, .markAsPlayed, .archive, .addToPlaylist, .star]
        guard let savedInts = UserDefaults.standard.object(forKey: Settings.upNextMultiSelectActionsKey) as? [Int32] else {
            return defaultActions
        }

        let actions = savedInts.compactMap { MultiSelectAction(rawValue: $0) }

        // Make sure new items are shown
        return actions + defaultActions.filter { !actions.contains($0) }
    }

    class func updateUpNextMultiSelectActions(_ actions: [MultiSelectAction]) {
        let actionInts = actions.map(\.rawValue)
        UserDefaults.standard.set(actionInts, forKey: Settings.upNextMultiSelectActionsKey)
    }

    // MARK: - Sleep Timer (internal)

    class var sleepTimerFinishedDate: Date? {
        set {
            UserDefaults.standard.set(newValue, forKey: Constants.UserDefaults.sleepTimerFinishedDate)
        }

        get {
            UserDefaults.standard.object(forKey: Constants.UserDefaults.sleepTimerFinishedDate) as? Date
        }
    }

    class var sleepTimerLastSetting: SleepTimerManager.SleepTimerSetting? {
        set {
            UserDefaults.standard.setJSONObject(newValue, forKey: Constants.UserDefaults.sleepTimerSetting)
        }

        get {
            try? UserDefaults.standard.jsonObject(SleepTimerManager.SleepTimerSetting.self, forKey: Constants.UserDefaults.sleepTimerSetting)
        }
    }

    // MARK: - End of Year 2022

    class func showBadgeForEndOfYear(_ year: Int) -> Bool {
        let key = String(format: Constants.UserDefaults.showBadgeForEndOfYear, year)
        return UserDefaults.standard.bool(forKey: key)
    }

    class func setShowBadgeForEndOfYear(_ newValue: Bool, year: Int) {
        let key = String(format: Constants.UserDefaults.showBadgeForEndOfYear, year)
        UserDefaults.standard.set(newValue, forKey: key)
    }

    class func hasShownModalForEndOfYear(_ year: Int) -> Bool {
        let key = String(format: Constants.UserDefaults.modalHasBeenShown, year)
        return UserDefaults.standard.bool(forKey: key)
    }

    class func setHasShownModalForEndOfYear(_ newValue: Bool, year: Int) {
        let key = String(format: Constants.UserDefaults.modalHasBeenShown, year)
        UserDefaults.standard.set(newValue, forKey: key)
    }

    static var shouldShowInitialOnboardingFlow: Bool {
        set {
            UserDefaults.standard.set(newValue, forKey: Constants.UserDefaults.shouldShowInitialOnboardingFlow)
        }
        get {
            UserDefaults.standard.bool(forKey: Constants.UserDefaults.shouldShowInitialOnboardingFlow)
        }
    }

    static var hasSeenInitialOnboardingBefore: Bool {
        get {
            UserDefaults.standard.object(forKey: Constants.UserDefaults.shouldShowInitialOnboardingFlow) != nil
        }
    }

    // MARK: - Embedded Artwork

    static var loadEmbeddedImages: Bool {
        get {
            UserDefaults.standard.bool(forKey: Constants.UserDefaults.loadEmbeddedImages)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Constants.UserDefaults.loadEmbeddedImages)
        }
    }

    // MARK: - Autoplay

    static var autoplay: Bool {
        set {
            UserDefaults.standard.set(newValue, forKey: Constants.UserDefaults.autoplay)
        }
        get {
            UserDefaults.standard.bool(forKey: Constants.UserDefaults.autoplay)
        }
    }

    // MARK: - Audio only

    /// When enabled, video episodes play as audio only. Backed by `ServerSettings` so it syncs with the server.
    static var audioOnly: Bool {
        set {
            ServerSettings.setAudioOnly(newValue)
        }
        get {
            ServerSettings.audioOnly()
        }
    }

    // MARK: - Sleep Timer

    static var autoRestartSleepTimer: Bool {
        set {
            UserDefaults.standard.set(newValue, forKey: Constants.UserDefaults.autoRestartSleepTimer)
        }
        get {
            UserDefaults.standard.object(forKey: Constants.UserDefaults.autoRestartSleepTimer) as? Bool ?? true
        }
    }

    static var shakeToRestartSleepTimer: Bool {
        set {
            UserDefaults.standard.set(newValue, forKey: Constants.UserDefaults.shakeToRestartSleepTimer)
        }
        get {
            UserDefaults.standard.bool(forKey: Constants.UserDefaults.shakeToRestartSleepTimer)
        }
    }

    // MARK: - Headphone Controls

    static var headphonesPreviousAction: HeadphoneControlAction {
        get {
            Constants.UserDefaults.headphones.previousAction.value
        }

        set {
            Constants.UserDefaults.headphones.previousAction.save(newValue)
        }
    }

    static var headphonesNextAction: HeadphoneControlAction {
        get {
            Constants.UserDefaults.headphones.nextAction.value
        }

        set {
            Constants.UserDefaults.headphones.nextAction.save(newValue)
        }
    }

    /// Returns whether the bookmark creation sound option is enabled
    static var isPlayBookmarkCreationSoundAvailable: Bool {
        [Settings.headphonesNextAction, Settings.headphonesPreviousAction].contains(.addBookmark)
    }

    /// Determines if we should play the sound when a bookmark is created
    static var shouldPlayBookmarkSound: Bool {
        isPlayBookmarkCreationSoundAvailable && playBookmarkCreationSound
    }

    static var playBookmarkCreationSound: Bool {
        get {
            Constants.UserDefaults.bookmarks.creationSound.value
        }

        set {
            Constants.UserDefaults.bookmarks.creationSound.save(newValue)
        }
    }

    static var darkUpNextTheme: Bool {
        get {
            Constants.UserDefaults.appearance.darkUpNextTheme.value
        }

        set {
            Constants.UserDefaults.appearance.darkUpNextTheme.save(newValue)
        }
    }

    static var tabBarMinimizingEnabled: Bool {
        get { Constants.UserDefaults.appearance.tabBarMinimizingEnabled.value }
        set { Constants.UserDefaults.appearance.tabBarMinimizingEnabled.save(newValue) }
    }

    static var skipBackTime: Int {
        get {
            ServerSettings.skipBackTime()
        }
        set {
            ServerSettings.setSkipBackTime(newValue)
        }
    }

    static var skipForwardTime: Int {
        get {
            ServerSettings.skipForwardTime()
        }
        set {
            ServerSettings.setSkipForwardTime(newValue)
        }
    }

    static var playerBookmarksSort: Binding<BookmarkSortOption> {
        Binding {
            Constants.UserDefaults.bookmarks.playerSort.value
        } set: { newValue in
            Constants.UserDefaults.bookmarks.playerSort.save(newValue)
        }
    }

    static var episodeBookmarksSort: Binding<BookmarkSortOption> {
        Binding {
            Constants.UserDefaults.bookmarks.episodeSort.value
        } set: { newValue in
            Constants.UserDefaults.bookmarks.episodeSort.save(newValue)
        }
    }

    static var podcastBookmarksSort: Binding<BookmarkSortOption> {
        Binding {
            Constants.UserDefaults.bookmarks.podcastSort.value
        } set: { newValue in
            Constants.UserDefaults.bookmarks.podcastSort.save(newValue)
        }
    }

    static var profileBookmarksSort: Binding<BookmarkSortOption> {
        Binding {
            Constants.UserDefaults.bookmarks.profileSort.value
        } set: { newValue in
            Constants.UserDefaults.bookmarks.profileSort.save(newValue)
        }
    }

    static var appBadge: AppBadge? {
        get {
            AppBadge(rawValue: Int32(UserDefaults.standard.integer(forKey: Constants.UserDefaults.appBadge)))
        }
        set {
            UserDefaults.standard.set(newValue?.rawValue, forKey: Constants.UserDefaults.appBadge)
        }
    }

    static var appBadgeFilterUuid: String? {
        get {
            UserDefaults.standard.string(forKey: Constants.UserDefaults.appBadgeFilterUuid)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Constants.UserDefaults.appBadgeFilterUuid)
        }
    }

    // MARK: - Podcast Feed Reload

    static var shouldShowPodcastFeeReloadTip: Bool {
        get {
            UserDefaults.standard.value(forKey: Constants.UserDefaults.podcastFeedReload.showTip) as? Bool ?? true
        }
        set {
            UserDefaults.standard.setValue(newValue, forKey: Constants.UserDefaults.podcastFeedReload.showTip)
        }
    }

    // MARK: - Manage Downloads

    class var manageDownloadsLastCheckDate: Date? {
        set {
            UserDefaults.standard.set(newValue, forKey: Constants.UserDefaults.manageDownloads.lastCheckDate)
        }

        get {
            UserDefaults.standard.object(forKey: Constants.UserDefaults.manageDownloads.lastCheckDate) as? Date
        }
    }

    // MARK: - Podcast View Changes Tip

    static var shouldShowPodcastViewChangesTip: Bool {
        get {
            UserDefaults.standard.value(forKey: Constants.UserDefaults.podcastViewChanges.showTip) as? Bool ?? true
        }
        set {
            UserDefaults.standard.setValue(newValue, forKey: Constants.UserDefaults.podcastViewChanges.showTip)
        }
    }

    // MARK: - Recent Played Sorting Tip

    static var shouldShowRecentlyPlayedSortingTip: Bool {
        get {
            UserDefaults.standard.value(forKey: Constants.UserDefaults.shouldShowRecentlyPlayedSortingTip) as? Bool ?? true
        }
        set {
            UserDefaults.standard.setValue(newValue, forKey: Constants.UserDefaults.shouldShowRecentlyPlayedSortingTip)
        }
    }

    // MARK: - Up Next Sort by Duration Tip

    // Defaults to true so upgrading users are told about the new duration sort once; AppDelegate suppresses it for fresh installs.
    static var shouldShowUpNextSortDurationTip: Bool {
        get {
            UserDefaults.standard.value(forKey: Constants.UserDefaults.shouldShowUpNextSortDurationTip) as? Bool ?? true
        }
        set {
            UserDefaults.standard.setValue(newValue, forKey: Constants.UserDefaults.shouldShowUpNextSortDurationTip)
        }
    }

    // MARK: - Smart Bookmarks Promo

    static var shouldShowBookmarksPlayerTip: Bool {
        get {
            UserDefaults.standard.value(forKey: Constants.UserDefaults.bookmarks.showPlayerTip) as? Bool ?? true
        }
        set {
            UserDefaults.standard.setValue(newValue, forKey: Constants.UserDefaults.bookmarks.showPlayerTip)
        }
    }

    // MARK: - Playlists

    static var shouldShowNewFilterTip: Bool {
        get {
            UserDefaults.standard.value(forKey: Constants.UserDefaults.newFilterTip) as? Bool ?? true
        }
        set {
            UserDefaults.standard.setValue(newValue, forKey: Constants.UserDefaults.newFilterTip)
        }
    }

    static var shouldShowNewFilterTipInCreationView: Bool {
        get {
            UserDefaults.standard.value(forKey: Constants.UserDefaults.newFilterTipCreationView) as? Bool ?? true
        }
        set {
            UserDefaults.standard.setValue(newValue, forKey: Constants.UserDefaults.newFilterTipCreationView)
        }
    }

    static var shouldShowDragAndDropTip: Bool {
        get {
            UserDefaults.standard.value(forKey: Constants.UserDefaults.playlistDragAndDropTip) as? Bool ?? false
        }
        set {
            UserDefaults.standard.setValue(newValue, forKey: Constants.UserDefaults.playlistDragAndDropTip)
        }
    }

    static var shouldShowPlaylistsOnboarding: Bool {
        get {
            UserDefaults.standard.value(forKey: Constants.UserDefaults.playlistsOnboarding) as? Bool ?? true
        }
        set {
            UserDefaults.standard.setValue(newValue, forKey: Constants.UserDefaults.playlistsOnboarding)
        }
    }

    static var firstTimePlaylistCreated: Bool {
        get {
            UserDefaults.standard.value(forKey: Constants.UserDefaults.firstTimePlaylistCreated) as? Bool ?? true
        }
        set {
            UserDefaults.standard.setValue(newValue, forKey: Constants.UserDefaults.firstTimePlaylistCreated)
        }
    }

    static var saveCurrentUpNextQueueIntoPlaylist: Bool {
        get {
            UserDefaults.standard.value(forKey: Constants.UserDefaults.saveCurrentUpNextQueueIntoPlaylist) as? Bool ?? true
        }
        set {
            UserDefaults.standard.setValue(newValue, forKey: Constants.UserDefaults.saveCurrentUpNextQueueIntoPlaylist)
        }
    }

    // MARK: - Notifications
    static var notificationsNewEpisodes: Bool {
        get {
            UserDefaults.standard.value(forKey: Constants.UserDefaults.notifications.newEpisodes) as? Bool ?? false
        }
        set {
            UserDefaults.standard.setValue(newValue, forKey: Constants.UserDefaults.notifications.newEpisodes)
        }
    }

    static var notificationsDailyReminders: Bool {
        get {
            UserDefaults.standard.value(forKey: Constants.UserDefaults.notifications.dailyReminders) as? Bool ?? false
        }
        set {
            UserDefaults.standard.setValue(newValue, forKey: Constants.UserDefaults.notifications.dailyReminders)
        }
    }

    static var notificationsNewFeaturesAndTips: Bool {
        get {
            UserDefaults.standard.value(forKey: Constants.UserDefaults.notifications.newFeaturesAndTips) as? Bool ?? false
        }
        set {
            UserDefaults.standard.setValue(newValue, forKey: Constants.UserDefaults.notifications.newFeaturesAndTips)
        }
    }

    static var notificationsLastTriggerDate: [String: Date] {
        get {
            UserDefaults.standard.value(forKey: Constants.UserDefaults.notifications.triggerDates) as? [String: Date] ?? [:]
        }
        set {
            UserDefaults.standard.setValue(newValue, forKey: Constants.UserDefaults.notifications.triggerDates)
        }
    }

    // MARK: - VoiceBoostN

    static var isVoiceBoostNEnabled: Bool {
        get {
            guard FeatureFlag.voiceBoostN.enabled else { return false }
            if UserDefaults.standard.object(forKey: Constants.UserDefaults.voiceBoostNEnabled) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: Constants.UserDefaults.voiceBoostNEnabled)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Constants.UserDefaults.voiceBoostNEnabled)
            FileLog.shared.addMessage("[Settings] VoiceBoostN \(newValue ? "enabled" : "disabled")")
        }
    }

    // MARK: - Database (internal)

    class var upgradedIndexes: Bool {
        set {
            UserDefaults.standard.setValue(newValue, forKey: "upgraded_indexes_v4")
        }

        get {
            UserDefaults.standard.bool(forKey: "upgraded_indexes_v4")
        }
    }

    class var lastAppVersionThatRunVacuum: String? {
        set {
            UserDefaults.standard.setValue(newValue, forKey: "last_app_version_that_run_vacuum")
        }

        get {
            UserDefaults.standard.string(forKey: "last_app_version_that_run_vacuum")
        }
    }

    // MARK: - Fixed configuration values

    #if !os(watchOS)
        class func podcastSearchDebounceTime() -> TimeInterval {
            Constants.ConfigDefaults.podcastSearchDebounceMsDefault / 1000
        }

        class func episodeSearchDebounceTime() -> TimeInterval {
            Constants.ConfigDefaults.episodeSearchDebounceMsDefault / 1000
        }

        static var addMissingEpisodes: Bool {
            Constants.ConfigDefaults.addMissingEpisodesDefault
        }
    #endif
}

extension HeadphoneControl {
    init(action: HeadphoneControlAction) {
        switch action {
        case .addBookmark:
            self = .addBookmark
        case .nextChapter:
            self = .nextChapter
        case .previousChapter:
            self = .previousChapter
        case .skipBack:
            self = .skipBack
        case .skipForward:
            self = .skipForward
        }
    }

    var action: HeadphoneControlAction {
        switch self {
        case .addBookmark:
            return .addBookmark
        case .nextChapter:
            return .nextChapter
        case .previousChapter:
            return .previousChapter
        case .skipBack:
            return .skipBack
        case .skipForward:
            return .skipForward
        }
    }
}

extension UserDefaults {
    var playerActions: [PlayerAction]? {
        guard let savedInts = UserDefaults.standard.object(forKey: Settings.playerActionsKey) as? [Int] else {
            return nil
        }

        return savedInts
            .compactMap { PlayerAction(int: $0) }
            .filter { $0.isAvailable }
    }
}
