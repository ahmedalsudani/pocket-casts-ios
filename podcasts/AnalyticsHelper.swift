import Foundation
import PocketCastsUtils

/// Telemetry has been removed. Every method on AnalyticsHelper is a no-op
/// shim — the surface is preserved purely so existing call sites continue
/// to compile.
class AnalyticsHelper {
    static var optedOut: Bool {
        #if APPCLIP
        return true
        #else
        return Settings.analyticsOptOut()
        #endif
    }

    class func openedCategory(categoryId: Int, region: String) {}
    class func openedFeaturedPodcast() {}
    class func subscribedToFeaturedPodcast() {}
    class func userGuideOpened() {}
    class func userGuideEmail(feedback: Bool) {}
    class func userGuideEmailSupport() {}
    class func userGuideEmailFeedback() {}
    class func downloadFromNotification() {}
    class func archiveFromNotification() {}
    class func addToUpNextFromNotification(playFirst: Bool) {}
    class func playNowFromNotification() {}
    class func sharedPodcast() {}
    class func sharedPodcastList() {}
    class func sharedEpisode() {}
    class func sharedEpisodeWithTimestamp() {}
    class func navigatedToDiscover() {}
    class func playedEpisode() {}
    class func subscribedToPodcast() {}

    // MARK: - List Analytics

    class func podcastEpisodePlayedFromList(listId: String, podcastUuid: String) {}
    class func podcastSubscribedFromList(listId: String, podcastUuid: String, listDateTime: String? = nil) {}
    class func podcastTappedFromList(listId: String, podcastUuid: String, listDateTime: String? = nil) {}
    class func adTapped(categoryName: String, region: String, podcastUUID: String, categoryID: Int) {}
    class func adSubscribed(categoryName: String, region: String, podcastUUID: String, categoryID: Int) {}
    class func podcastEpisodeTapped(fromList listId: String, podcastUuid: String, episodeUuid: String) {}
    class func listShowAllTapped(listId: String, dateTime: String? = nil) {}
    class func listImpression(listId: String, category: String?) {}
    class func bannerImpression(adID: String, location: String) {}
    class func bannerTapped(adID: String, location: String) {}
    class func bannerReport(adID: String, reason: String, location: String) {}

    // MARK: - Force Touch

    class func forceTouchPlay() {}
    class func forceTouchPause() {}
    class func forceTouchMarkPlayed() {}
    class func forceTouchTopFilter() {}
    class func forceTouchPodcast() {}
    class func forceTouchDiscover() {}

    class func didConnectToChromecast() {}
    class func didChooseIcon(iconName: String?) {}

    // MARK: - Siri

    class func siriSleeptimer() {}
    class func siriChapterChanged() {}
    class func siriSurpriseMe() {}
    class func siriUpNext() {}
    class func siriPause() {}
    class func siriResume() {}
    class func siriPlayPodcast() {}
    class func siriPlayAllFilter() {}
    class func siriPlayTopFilter() {}
    class func siriOpenFilter() {}

    // MARK: - Tours

    class func tourStarted(tourName: String) {}
    class func tourCompleted(tourName: String) {}
    class func tourCancelled(tourName: String, at step: Int) {}

    #if !os(watchOS) && !APPCLIP && !os(tvOS)
    class func tabSelected(tab: MainTabBarController.Tab) {}
    #endif

    class func nowPlayingOpened() {}
    class func upNextOpened() {}
    class func filterOpened() {}
    class func podcastOpened(uuid: String) {}
    class func episodeOpened(podcastUuid: String, episodeUuid: String) {}
    class func playerShowNotesOpened() {}
    class func chaptersOpened() {}
    class func accountDeleted() {}
}

// MARK: - Plus Upgrades

#if os(iOS)
extension AnalyticsHelper {
    static func plusUpgradeViewed(source: PlusUpgradeViewSource) {}
    static func plusUpgradeConfirmed(source: PlusUpgradeViewSource) {}
    static func plusUpgradeDismissed(source: PlusUpgradeViewSource) {}

    #if !APPCLIP
    static func plusAddToCart(identifier: IAPProductID) {}
    #endif

    static func plusPlanPurchased() {}
}

// MARK: - Account Creation

extension AnalyticsHelper {
    static func createAccountDismissed() {}
    static func createAccountConfirmed() {}
    static func createAccountSignIn() {}
}

// MARK: - Folders

extension AnalyticsHelper {
    static func folderCreated() {}
}
#endif
