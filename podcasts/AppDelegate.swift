import AppIntents
import BackgroundTasks
import Foundation
import PocketCastsDataModel
import PocketCastsServer
import PocketCastsUtils
import UIKit

class AppDelegate: UIResponder, UIApplicationDelegate {
    private static let initialRefreshDelay = 1.second
    private static let minTimeBetweenRefreshes = 5.minutes

    private let shortcutManager = ShortcutManager()
    private let badgeHelper = BadgeHelper()
    private let newEpisodeNotificationScheduler = NewEpisodeNotificationScheduler()

    @objc var backgroundSessionCompletionHandler: (() -> Void)?

    var window: UIWindow?
    var progressDialog: ShiftyLoadingAlert?

    private(set) var appInstallState: AppInstallState?

    // MARK: - App Lifecycle

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        ImageManager.readDisplayScale()
        ImageManager.setUpMemoryStorage()

        appInstallState = AppInstallState.check()

        if let appInstallState {
            switch appInstallState {
            case .updated:
                Settings.shouldShowNewFilterTip = false
                Settings.shouldShowNewFilterTipInCreationView = false
            case .installed:
                //Never show the podcast feed reload tooltip for fresh install
                Settings.shouldShowPodcastFeeReloadTip = false
                Settings.shouldShowPodcastViewChangesTip = false
                Settings.shouldShowRecentlyPlayedSortingTip = false
                Settings.shouldShowUpNextSortDurationTip = false
                Settings.shouldShowPlaylistsOnboarding = false
            case .sameVersion:
                break
            }
        }

        GoogleCastManager.shared.setup()

        setupRoutes()
        PocketCastsAppShortcutsProvider.updateAppShortcutParameters()

        NotificationsHelper.shared.register()

        DispatchQueue.global().async { [weak self] in
            guard let self else {
                return
            }

            ServerConfig.shared.syncDelegate = ServerSyncManager.shared
            ServerConfig.shared.playbackDelegate = PlaybackManager.shared
            checkDefaults()

            postLaunchSetup()
            checkIfRestoreCleanupRequired()

            ImageManager.shared.removeUnrequestedPodcastImages()
            ImageManager.shared.updatePodcastImagesIfRequired()
            WidgetHelper.shared.cleanupAppGroupImages()
            SiriShortcutsManager.shared.setup()

            DownloadManager.shared.startAllQueued()
        }

        badgeHelper.setup()
        WatchManager.shared.setup()
        shortcutManager.listenForShortcutChanges()

        setupBackgroundRefresh()

        return true
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        handleEnterBackground()
    }

    func handleEnterBackground() {
        scheduleNextBackgroundRefresh()
        FileLog.shared.forceFlush()

        UserDefaults.standard.set(Date(), forKey: Constants.UserDefaults.lastAppCloseDate)
        badgeHelper.updateBadge()

        NotificationsCoordinator.shared.handle(.applicationClosed)
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        handleBecomeActive()
    }

    func handleBecomeActive() {
        NotificationsCoordinator.shared.handle(.applicationOpened)

        // give the network a few seconds to come up before refreshing, also only refresh if the last refresh was more than 5 minutes ago
        let lastUpdateTime = ServerSettings.lastRefreshEndTime()
        if DateUtil.hasEnoughTimePassed(since: lastUpdateTime, time: AppDelegate.minTimeBetweenRefreshes) {
            Timer.scheduledTimer(withTimeInterval: AppDelegate.initialRefreshDelay, repeats: false, block: { _ in
                RefreshManager.shared.refreshPodcasts()
            })
        } else {
            DispatchQueue.global(qos: .userInitiated).async {
                PodcastManager.shared.checkForPendingAndAutoDownloads()
            }
        }
        PlaybackManager.shared.updateIdleTimer()
        PlaybackManager.shared.reconcileSleepTimerLiveActivity()
    }

    func application(_ application: UIApplication, handleEventsForBackgroundURLSession identifier: String, completionHandler: @escaping () -> Void) {
        backgroundSessionCompletionHandler = completionHandler
    }

    func application(_ application: UIApplication, didChangeStatusBarFrame oldStatusBarFrame: CGRect) {
        NotificationCenter.postOnMainThread(notification: Constants.Notifications.statusBarHeightChanged)
    }

    func applicationWillTerminate(_ application: UIApplication) {
        GoogleCastManager.shared.teardown()
        RefreshManager.shared.cancelAllRefreshes()

        badgeHelper.teardown()
        shortcutManager.stopListeningForShortcutChanges()

        UIApplication.shared.endReceivingRemoteControlEvents()
    }

    @objc func miniPlayer() -> MiniPlayerViewController? {
        NavigationManager.shared.miniPlayer
    }

    func openEpisode(_ episodeUuid: String, from podcast: Podcast, timestamp: TimeInterval? = nil) {
        DispatchQueue.main.async {
            self.hideProgressDialog()

            guard let episode = DataManager.shared.findEpisode(uuid: episodeUuid) else {
                // for some reason we can't find this episode, so open the podcast instead
                FileLog.shared.addMessage("Unable to find episode with uuid \(episodeUuid), opening podcast `\(podcast.title ?? "")` instead")
                NavigationManager.shared.navigateTo(NavigationManager.podcastPageKey, data: [NavigationManager.podcastKey: podcast])

                return
            }
            var data: [String: Any] = [NavigationManager.episodeUuidKey: episode.uuid]
            if let timestamp {
                data[NavigationManager.episodeTimestamp] = timestamp
            }

            NavigationManager.shared.navigateTo(NavigationManager.episodePageKey, data: data as NSDictionary)
        }
    }

    func hideProgressDialog() {
        if Thread.current.isMainThread {
            progressDialog?.hideAlert(false)
            progressDialog = nil
        } else {
            DispatchQueue.main.async {
                self.progressDialog?.hideAlert(false)
                self.progressDialog = nil
            }
        }
    }

    func openPlayerWhenReadyFromExternalEvent() {
        guard miniPlayer()?.playerOpenState != .open, miniPlayer()?.playerOpenState != .animating else { return }

        // when opening from an external event, we need to give the app time to set itself up and launch. As dodgy as this is, it means waiting a bit before launching the player
        SwiftUtils.performAfterDelayOnMainThread(1.0, closure: {
            guard let miniPlayer = self.miniPlayer(), miniPlayer.playerOpenState != .animating, miniPlayer.playerOpenState != .open else { return }

            miniPlayer.openFullScreenPlayer()
        })
    }

    private func setupBackgroundRefresh() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: Constants.Values.refreshTaskId, using: nil) { task in
            FileLog.shared.addMessage("Background refresh called")
            self.handleAppRefresh(task: task)
        }
    }

    private func scheduleNextBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: Constants.Values.refreshTaskId)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 30.minutes)

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            FileLog.shared.addMessage("Could not schedule app refresh: \(error.localizedDescription)")
        }
    }

    private func handleAppRefresh(task: BGTask) {
        scheduleNextBackgroundRefresh()

        let startDate = Date()
        task.expirationHandler = {
            FileLog.shared.addMessage("Background refresh timed out after \(startDate.elapsedTimeDescription)")
        }

        RefreshManager.shared.refreshPodcasts(completion: { refreshFetchResult in
            FileLog.shared.addMessage("Background refresh finished in \(startDate.elapsedTimeDescription) with result \(refreshFetchResult)")
            task.setTaskCompleted(success: refreshFetchResult != .failed)
        })
        badgeHelper.updateBadge()
    }

    private func postLaunchSetup() {
        if !UserDefaults.standard.bool(forKey: "CreatedDefPlaylistsV2") {
            PlaylistManager.createDefaultPlaylists()
            UserDefaults.standard.set(true, forKey: "CreatedDefPlaylistsV2")
        }
        Task {
            await DownloadManager.shared.clearStuckDownloads()
        }
    }

    private func checkIfRestoreCleanupRequired() {
        let dataManager = DataManager.shared

        // find the oldest episode in our database listed as being downloaded
        let query = "episodeStatus = \(DownloadStatus.downloaded.rawValue) ORDER BY publishedDate ASC, addedDate ASC LIMIT 1"
        guard let oldestEpisode = dataManager.findEpisodeWhere(customWhere: query, arguments: nil), !oldestEpisode.downloaded(pathFinder: DownloadManager.shared) else { return }

        // if we get here then we have at least one episode that is listed as downloaded that's actually not, so we need to go through and check them all
        FileLog.shared.addMessage("Detected restore cleanup required")
        let allQuery = "episodeStatus = \(DownloadStatus.downloaded.rawValue)"
        let downloadedEpisodes = dataManager.findEpisodesWhere(customWhere: allQuery, arguments: nil)
        for episode in downloadedEpisodes {
            if !episode.downloaded(pathFinder: DownloadManager.shared) {
                // episode is listed as downloaded, but the file isn't there, fix this
                dataManager.saveEpisode(downloadStatus: .notDownloaded, episode: episode)
                dataManager.saveFrameCount(episode: episode, frameCount: 0)
            }
        }

        NotificationCenter.postOnMainThread(notification: Constants.Notifications.manyEpisodesChanged)
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let role = connectingSceneSession.role

        if role == .carTemplateApplication {
            FileLog.shared.addMessage("AppDelegate: CarPlay isConnected")
            return UISceneConfiguration(name: "Pocket Casts Car", sessionRole: UISceneSession.Role.carTemplateApplication)
        }

        return UISceneConfiguration(name: "Default Configuration", sessionRole: role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
        let includesCarPlay = sceneSessions.contains(where: { $0.role == .carTemplateApplication })

        if includesCarPlay {
            FileLog.shared.addMessage("AppDelegate: CarPlay didDiscard")
        }
    }
}
