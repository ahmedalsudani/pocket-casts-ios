import PocketCastsDataModel
import PocketCastsServer
import SafariServices
import UIKit
import Combine
import PocketCastsUtils
import SwiftUI

class MainTabBarController: UITabBarController, NavigationProtocol {

    enum Tab: Int { case podcasts, filter, discover, profile, upNext }

    var pcTabs = [Tab]()

    let playPauseCommand = UIKeyCommand(title: L10n.keycommandPlayPause, action: #selector(handlePlayPauseKey), input: " ", modifierFlags: [])

    lazy var endOfYear = EndOfYear()

    /// Styles its badge as a plain red dot on the item itself, since Liquid Glass ignores the tab bar
    /// appearance that does it for the older tab bar.
    private lazy var profileTabBarItem: UITabBarItem = {
        let item = UITabBarItem(title: L10n.profile, image: UIImage(named: "profile_tab"), tag: pcTabs.firstIndex(of: .profile) ?? -1)
        item.badgeColor = .clear
        item.setBadgeTextAttributes([.foregroundColor: UIColor.systemRed], for: .normal)
        item.setBadgeTextAttributes([.foregroundColor: UIColor.systemRed], for: .selected)
        return item
    }()

    private lazy var upNextTabBarItem = UITabBarItem(title: L10n.upNext, image: UIImage(named: "upnext_tab"), tag: pcTabs.firstIndex(of: .upNext) ?? -1)

    /// The last Up Next count rendered into the tab, used to pulse the tab only
    /// when the queue actually changes (not on every refresh notification).
    private var previousUpNextCount: Int?

    /// `true` while the Up Next "pulse" spring is in flight, so a burst of
    /// rapid adds doesn't stack overlapping transforms on the target (the tab
    /// button, or the mini player artwork when minimized).
    /// Not `private`: set from the pulse code in `+Animations`.
    var isPulsingUpNextTarget = false


    /// The viewDidAppear can trigger more than once per lifecycle, setting this flag on the first did appear prevents use from prompting more than once per lifecycle. But still wait until the tab bar has appeared to do so.
    var viewDidAppearBefore: Bool = false

    /// Displayed during database migrations
    var alert: ShiftyLoadingAlert?

    private var miniPlayerBottomConstraint: NSLayoutConstraint?
    private var isMiniPlayerAnchoredToTabBar = false

    private var isShowingErrorToast = false
    private var dismissErrorWorkItem: DispatchWorkItem?

    // MARK: - State

    override func viewDidLoad() {
        super.viewDidLoad()

        registerForTraitChanges([UITraitUserInterfaceStyle.self, UITraitHorizontalSizeClass.self]) { (controller: MainTabBarController, _) in
            if let scene = controller.view.window?.windowScene {
                Theme.systemIsDark = (scene.traitCollection.userInterfaceStyle == .dark)
            }
            controller.fireSystemThemeMayHaveChanged()
        }

        pcTabs = [.podcasts, .filter, .discover, .upNext, .profile]

        var vcsInTab = [UIViewController]()

        let podcastsController = PodcastListViewController()
        podcastsController.tabBarItem = UITabBarItem(title: L10n.podcastsPlural, image: UIImage(named: "podcasts_tab"), tag: pcTabs.firstIndex(of: .podcasts)!)

        let filtersViewController = PlaylistsViewController()
        filtersViewController.tabBarItem = UITabBarItem(title: L10n.playlists, image: UIImage(named: "playlists_tab"), tag: pcTabs.firstIndex(of: .filter)!)

        let discoverViewController = DiscoverCollectionViewController()

        discoverViewController.tabBarItem = UITabBarItem(title: L10n.discover, image: UIImage(named: "discover_tab"), tag: pcTabs.firstIndex(of: .discover)!)

        let profileViewController = ProfileViewController()
        profileViewController.tabBarItem = profileTabBarItem

        let upNextViewController = UpNextViewController(showingInTab: true)
        upNextViewController.tabBarItem = upNextTabBarItem
        vcsInTab = [podcastsController, filtersViewController, discoverViewController, upNextViewController, profileViewController]

        displayEndOfYearBadgeIfNeeded()

        viewControllers = vcsInTab.map { SJUIUtils.navController(for: $0) }
        selectedIndex = UserDefaults.standard.integer(forKey: Constants.UserDefaults.lastTabOpened)

        NavigationManager.shared.mainViewControllerDidLoad(controller: self)
        setupMiniPlayer()
        updateTabBarColor()
        setupKeyboardShortcuts()

        NotificationCenter.default.addObserver(self, selector: #selector(themeDidChange), name: Constants.Notifications.themeChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(textEditingDidStart), name: Constants.Notifications.textEditingDidStart, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(textEditingDidEnd), name: Constants.Notifications.textEditingDidEnd, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleFollowSystemThemeTurnedOn), name: Constants.Notifications.followSystemThemeTurnedOn, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(willEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(profileSeen), name: Constants.Notifications.profileSeen, object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(refreshUpNextTabBadge), name: Constants.Notifications.upNextQueueChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(refreshUpNextTabBadge), name: Constants.Notifications.upNextEpisodeRemoved, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(refreshUpNextTabBadge), name: Constants.Notifications.playbackTrackChanged, object: nil)
        // `upNextEpisodeAdded` refreshes the badge via the genie animation's tail, not here.
        NotificationCenter.default.addObserver(self, selector: #selector(animateEpisodeAddedToUpNext(_:)), name: Constants.Notifications.upNextEpisodeAdded, object: nil)
        refreshUpNextTabBadge()

        addBookmarkCreatedToastHandler()
        if FeatureFlag.displayErrorsOnPlayer.enabled {
            setupErrorObservers()
        }
    }

    private var cancellables = Set<AnyCancellable>()

    private var systemAppearanceObservation: Any?

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        registerSceneAppearanceObserverIfNeeded()
        fireSystemThemeMayHaveChanged()

        // if this key was never set lets default to Discovery or Podcast depending of podcasts followed
        if UserDefaults.standard.object(forKey: Constants.UserDefaults.lastTabOpened) == nil {
            selectedIndex = DataManager.shared.podcastCount() > 0 ? Tab.podcasts.rawValue: Tab.discover.rawValue
        }

        updateDatabaseIndexes()
        optimizeDatabaseIfNeeded()

        let isFirstAppearance = !viewDidAppearBefore
        viewDidAppearBefore = true

        // This can run inside the deferred-commit flush of a modal dismissal, where
        // presenting or dismissing runs into the transition that is still tearing down.
        DispatchQueue.main.async { [weak self] in
            self?.showLaunchPromptsIfNeeded(isFirstAppearance: isFirstAppearance)
        }
    }

    /// Update database indexes and delete unused columns
    /// This is outside of migrations and done just once
    /// because for larger databases it's very time consuming
    private func updateDatabaseIndexes() {
        guard !Settings.upgradedIndexes else {
            return
        }

        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self else { return }

            if DataManager.shared.podcastCount() > 100 {
                self.presentLoader()
            }
            DataManager.shared.cleanUp()
            self.dismissLoader()
            Settings.upgradedIndexes = true
        }
    }

    private func optimizeDatabaseIfNeeded() {
        guard
            let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
            appVersion != Settings.lastAppVersionThatRunVacuum,
            FeatureFlag.runVacuumOnVersionUpdate.enabled
        else {
            return
        }
        Settings.lastAppVersionThatRunVacuum = appVersion
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self else { return }
            if DataManager.shared.podcastCount() > 100 {
                presentLoader()
            }
            DataManager.shared.vacuumDatabase()
            dismissLoader()
        }
    }

    private func showInitialOnboardingIfNeeded() {
        // Only prompt the first time the app is launched
        if Settings.shouldShowInitialOnboardingFlow == false && Settings.hasSeenInitialOnboardingBefore == true {
            return
        }

        // There is no account to set up, so the first launch only asks for notification permissions
        NavigationManager.shared.showNotificationsPermissionsModal()

        // Set the flag so the user won't see the on launch flow again
        Settings.shouldShowInitialOnboardingFlow = false
    }

    @objc func themeDidChange() {
        updateTabBarColor()
        setNeedsStatusBarAppearanceUpdate()
        refreshUpNextTabBadge()
    }

    private func setupMiniPlayer() {
        let miniPlayer = MiniPlayerViewController(nibName: "MiniPlayerViewController", bundle: nil)
        NavigationManager.shared.miniPlayer = miniPlayer

        if LiquidGlass.isEnabled, #available(iOS 26.0, *) {
            miniPlayer.hostTabBarController = self
            // Load the view so XIB outlets and observers are wired up before
            // it's installed as a tab accessory contentView.
            miniPlayer.loadViewIfNeeded()
        } else {
            miniPlayer.view.translatesAutoresizingMaskIntoConstraints = false
            if tabBar.superview === view {
                view.insertSubview(miniPlayer.view, belowSubview: tabBar)
            } else {
                view.addSubview(miniPlayer.view)
            }

            NSLayoutConstraint.activate([
                miniPlayer.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                miniPlayer.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
            ])
            anchorMiniPlayerToBottom()

            miniPlayer.changeHeightTo(miniPlayer.desiredHeight())
        }
    }

    /// On iOS 18 the tab bar floats at the top on regular width and isn't part of this view's
    /// hierarchy, so the mini player sits on the bottom safe area instead of on top of the tab bar.
    private func anchorMiniPlayerToBottom() {
        guard let miniPlayerView = NavigationManager.shared.miniPlayer?.view, miniPlayerView.superview === view else { return }
        let anchorsToTabBar = tabBar.isDescendant(of: view)
        guard miniPlayerBottomConstraint == nil || anchorsToTabBar != isMiniPlayerAnchoredToTabBar else { return }
        miniPlayerBottomConstraint?.isActive = false
        let bottomAnchor = anchorsToTabBar ? tabBar.topAnchor : view.safeAreaLayoutGuide.bottomAnchor
        miniPlayerBottomConstraint = miniPlayerView.bottomAnchor.constraint(equalTo: bottomAnchor)
        miniPlayerBottomConstraint?.isActive = true
        isMiniPlayerAnchoredToTabBar = anchorsToTabBar
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        anchorMiniPlayerToBottom()
    }

    // MARK: - UITabBarDelegate

    override func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
        let tabIndex = item.tag
        if tabIndex == selectedIndex, let navController = selectedViewController as? UINavigationController, navController.visibleViewController == navController.viewControllers.first {
            // the user has tapped on a tab they are already at the root of, so trigger an action so we can handle this
            NotificationCenter.postOnMainThread(notification: Constants.Notifications.tappedOnSelectedTab, object: tabIndex)
        }

        UserDefaults.standard.set(tabIndex, forKey: Constants.UserDefaults.lastTabOpened)
    }

    // MARK: - NavigationProtocol

    func showInSafariViewController(urlString: String) {
        guard let url = URL(string: urlString) else { return }

        let safariViewController = SFSafariViewController(with: url)
        topController().present(safariViewController, animated: true, completion: nil)
    }

    func navigateToPodcastList(_ animated: Bool) {
        if !switchToTab(.podcasts) { return }

        if let navController = selectedViewController as? UINavigationController {
            navController.popToRootViewController(animated: true)
        }
    }

    func navigateToFolder(_ folder: Folder, popToRootViewController: Bool = true) {
        guard let navController = selectedViewController as? UINavigationController else { return }

        if popToRootViewController {
            navController.popToRootViewController(animated: false)
        }

        let folderController = FolderViewController(folder: folder)
        navController.pushViewController(folderController, animated: true)
    }

    func navigateToPodcast(_ podcast: Podcast) {
        appDelegate()?.miniPlayer()?.closeUpNextAndFullPlayer(completion: { [weak self] in

            guard let strongSelf = self else { return }

            if let navController = strongSelf.selectedViewController as? UINavigationController {
                if let existingPodcastController = navController.topViewController as? PodcastViewController {
                    if let existingUuid = existingPodcastController.podcast?.uuid, existingUuid == podcast.uuid {
                        return // we're already on this podcast
                    } else {
                        navController.popViewController(animated: false)
                    }
                }

                let podcastController = PodcastViewController(podcast: podcast)
                navController.pushViewController(podcastController, animated: true)
            }
        })
    }

    func navigateToPodcastInfo(_ podcastInfo: PodcastInfo) {
        appDelegate()?.miniPlayer()?.closeUpNextAndFullPlayer(completion: { [weak self] in
            guard let navController = self?.selectedViewController as? UINavigationController else {
                return
            }

            navController.popToRootViewController(animated: false)
            let podcastController = PodcastViewController(podcastInfo: podcastInfo, existingImage: nil)
            navController.pushViewController(podcastController, animated: true)
        })
    }

    func navigateTo(podcast searchResult: PodcastFolderSearchResult) {
        if let navController = selectedViewController as? UINavigationController {
            let podcastController = PodcastViewController(podcastInfo: PodcastInfo(from: searchResult), existingImage: nil)
            navController.pushViewController(podcastController, animated: true)
        }
    }

    func navigateToEpisode(_ episodeUuid: String, podcastUuid: String?, timestamp: TimeInterval?) {
        if let navController = selectedViewController as? UINavigationController {
            navController.dismiss(animated: false, completion: nil)

            // I know it looks dodgy, but the episode card won't load properly if you just dismissed another view controller. Need to figure out the actual bug...but for now:
            // (before you ask, using the completion block doesn't work above, regardless of whether animated is true or false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5.seconds) {
                if EpisodeLoadingController.needsLoading(uuid: episodeUuid), let podcastUuid {
                    let episodeController = EpisodeLoadingController(episodeUuid: episodeUuid,
                                                                     podcastUuid: podcastUuid,
                                                                     timestamp: timestamp)

                    let nav = UINavigationController(rootViewController: episodeController)
                    nav.modalPresentationStyle = .formSheet
                    nav.isNavigationBarHidden = true

                    navController.present(nav, animated: true)
                } else {
                    let episodeController = EpisodeDetailViewController(episodeUuid: episodeUuid, timestamp: timestamp)
                    episodeController.modalPresentationStyle = .formSheet

                    navController.present(episodeController, animated: true)
                }
            }
        }
    }

    func navigateToDiscover(_ animated: Bool) {
        switchToTab(.discover)
    }

    func navigateToUpNext(_ animated: Bool) {
        switchToTab(.upNext)
    }

    func navigateToProfile(row: ProfileViewController.TableRow? = nil, animated: Bool) {
        guard let miniPlayer = NavigationManager.shared.miniPlayer, miniPlayer.playerOpenState != .animating else { return }

        miniPlayer.closeFullScreenPlayer { [weak self] in
            guard let self, switchToTab(.profile),
                  let navController = selectedViewController as? UINavigationController else {
                return
            }
            navController.popToRootViewController(animated: animated && row == nil)
            guard let profileViewController = navController.topViewController as? ProfileViewController,
                let row else {
                return
            }
            profileViewController.navigateToRow(row)
        }
    }

    func navigateToFilter(_ filter: EpisodeFilter?, animated: Bool) {
        guard switchToTab(.filter) else { return }

        guard let navController = selectedViewController as? UINavigationController else {
            return
        }
        navController.popToRootViewController(animated: false)

        guard let filter,
              let filtersViewController = navController.topViewController as? PlaylistsViewController else {
            return
        }
        filtersViewController.showFilter(filter)
    }

    func navigateToAddFilter() {
        guard switchToTab(.filter),
              let navController = selectedViewController as? UINavigationController else {
            return
        }
        navController.popToRootViewController(animated: false)

        (navController.topViewController as? PlaylistsViewController)?.presentFilterPreview()
    }

    func presentManualPlaylistsChooser(for episode: Episode, rootViewController: UIViewController?) {
        guard let navController = selectedViewController as? UINavigationController else {
            return
        }
        let manualPlaylistsChooser = ManualPlaylistsChooserViewController(episode: episode)
        let navVC = SJUIUtils.navController(for: manualPlaylistsChooser)
        if presentedViewController is PlayerContainerViewController {
            presentedViewController?.present(navVC, animated: true, completion: nil)
        } else {
            let root = rootViewController ?? navController.topViewController
            root?.present(navVC, animated: true, completion: nil)
        }
    }

    func navigateToAddCustom(_ url: URL) {
        appDelegate()?.miniPlayer()?.closeUpNextAndFullPlayer(completion: {
            self.switchToTab(.profile)

            if let navController = self.selectedViewController as? UINavigationController {
                if let existingUploadedViewController = (navController.viewControllers.last as? UploadedViewController) {
                    existingUploadedViewController.closeAllChildrenViewControllers()
                }
                navController.popToRootViewController(animated: false)

                let uploadedViewController = UploadedViewController()
                uploadedViewController.fileURL = url
                navController.pushViewController(uploadedViewController, animated: false)
            }
        })
    }

    func navigateToFiles() {
        switchToTab(.profile)

        if let navController = selectedViewController as? UINavigationController {
            navController.popToRootViewController(animated: false)

            let filesController = UploadedViewController()
            navController.pushViewController(filesController, animated: true)
        }
    }

    func navigateToFilterTab() {
        switchToTab(.filter)
    }

    func showSettings(row: SettingsViewController.TableRow?) {
        switchToTab(.profile)
        guard let navController = selectedViewController as? UINavigationController else { return }

        if navController.presentedViewController != nil {
            navController.dismiss(animated: false)
        }

        navController.popToRootViewController(animated: false)
        let settingViewController = SettingsViewController()
        navController.pushViewController(settingViewController, animated: row == nil)

        guard let row else { return }

        settingViewController.selectRow(row)
    }

    func showSettingsAppearance(showThemeSelection: Bool = false) {
        switchToTab(.profile)
        if let navController = selectedViewController as? UINavigationController {
            navController.popToRootViewController(animated: false)

            navController.pushViewController(SettingsViewController(), animated: false)
            let appearanceViewController = AppearanceViewController()
            navController.pushViewController(appearanceViewController, animated: !showThemeSelection)
            if showThemeSelection {
                appearanceViewController.presentThemePicker(selectedTheme: Theme.preferredLightTheme()) { theme in
                    Theme.setPreferredLightTheme(theme, systemIsDark: Theme.systemIsDark)
                }
            }
        }
    }

    func showHeadphoneSettings() {
        let state = NavigationManager.shared.miniPlayer?.playerOpenState

        // Dismiss any presented views if the player is not already open/dismissing since it will dismiss itself
        if state != .open, state != .animating {
            dismissPresentedViewController()
        }

        switchToTab(.profile)
        if let navController = selectedViewController as? UINavigationController {
            navController.popToRootViewController(animated: false)
            navController.pushViewController(SettingsViewController(), animated: false)
            navController.pushViewController(HeadphoneSettingsViewController(), animated: true)
        }
    }

    func showGeneralSettings(row: GeneralSettingsViewController.TableRow?) {
        let state = NavigationManager.shared.miniPlayer?.playerOpenState

        // Dismiss any presented views if the player is not already open/dismissing since it will dismiss itself
        if state != .open, state != .animating {
            dismissPresentedViewController()
        }

        switchToTab(.profile)
        if let navController = selectedViewController as? UINavigationController {
            navController.popToRootViewController(animated: false)
            navController.pushViewController(SettingsViewController(), animated: false)
            let generalSettingsController = GeneralSettingsViewController()
            generalSettingsController.scrollToRow = row
            navController.pushViewController(generalSettingsController, animated: true)
        }
    }

    func showEndOfYearStories() {
        guard let presentedViewController else {
            endOfYear.showStories(in: self)
            return
        }

        presentedViewController.dismiss(animated: true) {
            self.endOfYear.showStories(in: self)
        }
    }

    func dismissPresentedViewController(completion: (() -> Void)? = nil) {
        presentedViewController?.dismiss(animated: true, completion: completion)
    }

    private func topController() -> UIViewController {
        var topController: UIViewController = self
        while let presentedViewController = topController.presentedViewController {
            topController = presentedViewController
        }

        return topController
    }

    @discardableResult
    private func switchToTab(_ tab: Tab) -> Bool {
        guard let miniPlayer = NavigationManager.shared.miniPlayer else { return false }

        if miniPlayer.playerOpenState == .animating {
            return false // can't switch tabs while animating
        }

        if miniPlayer.playerOpenState == .open {
            miniPlayer.closeFullScreenPlayer()
        }

        selectedIndex = pcTabs.firstIndex(of: tab)!

        return true
    }

    // MARK: - End of Year

    /// Whether End of Year has a badge waiting on the Profile tab, which it shares with What's New.
    private var showsEndOfYearBadge = false

    @objc private func profileSeen() {
        showsEndOfYearBadge = false
        updateProfileTabBadge()
        if let year = endOfYear.storyModelType?.year {
            Settings.setShowBadgeForEndOfYear(false, year: year)
        }
    }

    // MARK: - Orientation

    // we implement this here to lock all views (except presented modal VCs to portrait)
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        .portrait
    }

    // MARK: - End of Year

    private func updateTabBarColor() {
        tabBar.unselectedItemTintColor = AppTheme.unselectedTabBarItemColor
        tabBar.tintColor = AppTheme.tabBarItemTintColor

        // Liquid Glass renders its own translucent material, so skip the opaque
        // background appearance below — but the theme tint above must still apply.
        guard !LiquidGlass.isEnabled else { return }

        self.view.backgroundColor = AppTheme.viewBackgroundColor

        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = AppTheme.tabBarBackgroundColor

        // Change badge colors
        [appearance.stackedLayoutAppearance,
         appearance.inlineLayoutAppearance,
         appearance.compactInlineLayoutAppearance]
            .forEach {
                $0.normal.badgeBackgroundColor = .clear
                $0.normal.badgeTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor.systemRed]
            }

        tabBar.standardAppearance = appearance
        tabBar.scrollEdgeAppearance = appearance
    }

    private func displayEndOfYearBadgeIfNeeded() {
        if EndOfYear.isEligible, let year = endOfYear.storyModelType?.year, Settings.showBadgeForEndOfYear(year) {
            showsEndOfYearBadge = true
            updateProfileTabBadge()
        }
    }

    @objc private func willEnterForeground() {
        fireSystemThemeMayHaveChanged()
    }

    // The window's `overrideUserInterfaceStyle` masks system appearance changes
    // from view controllers inside it, so `traitCollectionDidChange` never fires
    // for system light/dark flips. Observe at the scene level instead — scene
    // traits aren't affected by the per-window override.
    private func registerSceneAppearanceObserverIfNeeded() {
        guard systemAppearanceObservation == nil,
              LiquidGlass.isEnabled,
              let scene = view.window?.windowScene else { return }
        systemAppearanceObservation = scene.registerForTraitChanges(
            [UITraitUserInterfaceStyle.self]
        ) { [weak self] (scene: UIWindowScene, _: UITraitCollection) in
            Theme.systemIsDark = (scene.traitCollection.userInterfaceStyle == .dark)
            self?.fireSystemThemeMayHaveChanged()
        }
    }

    private var lastNotifiedAboutDark: Bool?
    private func fireSystemThemeMayHaveChanged() {
        if !Settings.shouldFollowSystemTheme { return } // if the user has turned this off, then ignore system theme changes

        let isDark = Theme.systemIsDark
        if lastNotifiedAboutDark == nil || isDark != lastNotifiedAboutDark {
            lastNotifiedAboutDark = isDark
            NotificationCenter.postOnMainThread(notification: Constants.Notifications.systemThemeMayHaveChanged, object: isDark)
        }
    }

    @objc private func handleFollowSystemThemeTurnedOn() {
        lastNotifiedAboutDark = nil
        fireSystemThemeMayHaveChanged()
    }

    // There are different areas of the app that relies on presenting VCs from the tab bar
    // However, sometimes the tab bar is already displaying the player.
    // This code simple checks if the tab bar is already presenting something and, if yes,
    // present the VC through the presentedViewController
    override func present(_ viewControllerToPresent: UIViewController, animated flag: Bool, completion: (() -> Void)? = nil) {
        if let presentedViewController, !presentedViewController.isBeingDismissed {
            presentedViewController.present(viewControllerToPresent, animated: flag, completion: completion)
            return
        }

        super.present(viewControllerToPresent, animated: flag, completion: completion)
    }

    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        super.motionEnded(motion, with: event)
        if motion == .motionShake && Settings.shakeToRestartSleepTimer {
            PlaybackManager.shared.restartSleepTimer()
        }
    }
}

// MARK: - Bookmarks

private extension MainTabBarController {
    // Shows a toast notification when a bookmark is created and we're not in the full screen player
    func addBookmarkCreatedToastHandler() {
        let bookmarkManager = PlaybackManager.shared.bookmarkManager

        bookmarkManager.onBookmarkCreated
            .receive(on: RunLoop.main)
            .filter { event in
                !event.isFromTranscript
                && UIApplication.shared.applicationState == .active
                && !CarPlayHelper.isConnectedToCarPlay
                && NavigationManager.shared.miniPlayer?.playerOpenState == .closed
            }
            .compactMap { event in
                bookmarkManager.bookmark(for: event.uuid)
            }
            .sink { [weak self] bookmark in
                self?.showToast(for: bookmark)
            }
            .store(in: &cancellables)
    }

    func showToast(for bookmark: Bookmark) {
        let bookmarkManager = PlaybackManager.shared.bookmarkManager

        let title = bookmark.title
        let message = title == L10n.bookmarkDefaultTitle ? L10n.bookmarkAdded : L10n.bookmarkAddedNotification(title)

        let action = Toast.Action(title: L10n.changeBookmarkTitle) { [weak self] in
            // Re-read: a generated title may have been saved since the toast was shown
            let bookmark = bookmarkManager.bookmark(for: bookmark.uuid) ?? bookmark
            let title = bookmark.title

            let controller = BookmarkEditTitleViewController(manager: bookmarkManager, bookmark: bookmark, state: .updating, style: .themed, onDismiss: { [weak self] outcome in
                guard case .saved(let updatedTitle) = outcome, title != updatedTitle else { return }

                self?.handleBookmarkTitleUpdated(updatedTitle: updatedTitle)
            })

            self?.presentFromRootController(controller)
        }

        Toast.show(message, actions: [action], theme: .playerTheme)
    }

    func handleBookmarkTitleUpdated(updatedTitle: String) {
        Toast.show(L10n.bookmarkUpdatedNotification(updatedTitle), actions: [
            .init(title: L10n.bookmarkAddedButtonTitle, action: { [weak self] in
                self?.showBookmarksInPlayer()
            })
        ], theme: .playerTheme)
    }

    func showBookmarksInPlayer() {
        dismissIfNeeded {
            NavigationManager.shared.miniPlayer?.openFullScreenPlayer {
                NavigationManager.shared.miniPlayer?.fullScreenPlayer?.scrollToBookmarks()
            }
        }
    }
}

// MARK: - App Launch Prompts

private extension MainTabBarController {
    func showLaunchPromptsIfNeeded(isFirstAppearance: Bool) {
        // Show any app launch prompts only once
        if isFirstAppearance {
            showEndOfYearPromptIfNeeded()
        }

        showInitialOnboardingIfNeeded()
    }

    func showEndOfYearPromptIfNeeded() {
        endOfYear.showPromptBasedOnState(in: self)
    }
}

// MARK: - Notifications

extension MainTabBarController {

    func showNotificationsPermissions() {
        // Skip when another flow is already presenting, since we can't stack on it.
        guard presentedViewController == nil else { return }
        present(NotificationsPermissionsViewModel.makeController(), animated: true)
    }
}

// MARK: - Error Status

extension MainTabBarController {

    private func setupErrorObservers() {
        let errorRelevantNotifications = Set([Constants.Notifications.playbackFailed, Constants.Notifications.playbackStarted, Constants.Notifications.playbackPaused])

        for notificationName in errorRelevantNotifications {
            NotificationCenter.default.addObserver(self, selector: #selector(updateError(notification:)), name: notificationName, object: nil)
        }
    }

    @objc private func updateError(notification: NSNotification) {
        DispatchQueue.main.async { [weak self] in
            guard FeatureFlag.displayErrorsOnPlayer.enabled,
                let error = PlaybackManager.shared.activeError else {
                self?.hideError()
                return
            }
            if self?.isShowingErrorToast == false {
                self?.showError(error, autoDismissAfter: 5)
            }
        }
    }

    private func showError(_ error: PlaybackManager.PlaybackError, autoDismissAfter seconds: TimeInterval) {
        // the full screen player shows the error itself
        guard !(presentedViewController is PlayerContainerViewController) else { return }

        Toast.show(error.shortUserMessage, dismissAfter: .interval(seconds), bottomInset: toastBottomInset)

        isShowingErrorToast = true
        dismissErrorWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in self?.isShowingErrorToast = false }
        dismissErrorWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: item)
    }

    /// The distance from the bottom of the window to the top of the tab bar or the mini player, whichever is higher.
    private var toastBottomInset: CGFloat {
        guard let window = view.window else { return 0 }
        var top = window.bounds.height - window.safeAreaInsets.bottom
        let tabBarTop = tabBar.convert(tabBar.bounds, to: nil).minY
        if tabBarTop > window.bounds.midY {
            top = min(top, tabBarTop)
        }
        if let miniPlayerView = NavigationManager.shared.miniPlayer?.view, miniPlayerView.window != nil, !miniPlayerView.isHidden {
            let frame = miniPlayerView.convert(miniPlayerView.bounds, to: nil)
            if frame.height > 0 {
                top = min(top, frame.minY)
            }
        }
        return max(0, window.bounds.height - top)
    }

    private func hideError() {
        guard isShowingErrorToast else { return }
        isShowingErrorToast = false
        dismissErrorWorkItem?.cancel()
        Toast.dismiss()
    }
}

// MARK: - Up Next tab badge

extension MainTabBarController {
    @objc func refreshUpNextTabBadge() {
        guard #available(iOS 26.0, *) else { return }

        // Clamping lives in `composeUpNextTabImage`; track the true count here.
        let count = PlaybackManager.shared.queue.upNextCount()
        let previous = previousUpNextCount
        previousUpNextCount = count

        // Nothing to redraw if the count didn't move. The composed image is a
        // template, so the tab bar re-tints it on theme changes for free — no
        // rebuild needed there either.
        guard count != previous else { return }

        guard count > 0 else {
            resetUpNextTabImage()
            return
        }

        // A template image so the tab bar tints it like every other item.
        upNextTabBarItem.image = Self.composeUpNextTabImage(count: count)
        upNextTabBarItem.selectedImage = Self.composeUpNextTabImage(count: count, isSelected: true)

        // Only celebrate the queue growing — a drain (playing/removing) shouldn't pop.
        if previous.map({ count > $0 }) ?? false { pulseUpNextTarget() }
    }

    func resetUpNextTabImage() {
        upNextTabBarItem.image = UIImage(named: "upnext_tab")
        upNextTabBarItem.selectedImage = nil
    }
}

// MARK: - Profile tab badge

private extension MainTabBarController {
    /// Shows the dot while End of Year has something waiting on Profile.
    func updateProfileTabBadge() {
        profileTabBarItem.badgeValue = showsEndOfYearBadge ? "●" : nil
    }
}
