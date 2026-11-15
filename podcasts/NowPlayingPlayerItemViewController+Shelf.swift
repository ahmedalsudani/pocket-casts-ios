import AVKit
import PocketCastsServer
import UIKit
import PocketCastsDataModel
import PocketCastsUtils

@MainActor
protocol NowPlayingActionsDelegate: AnyObject {
    func starEpisodeTapped()
    func effectsTapped()
    func sleepTimerTapped()
    func routePickerTapped()
    func shareTapped()
    func goToTapped()
    func chromecastTapped()
    func markPlayedTapped()
    func archiveTapped()
    func bookmarkTapped()
    func transcriptTapped()
    func downloadTapped()
    func videoToggleTapped()
    func sharedRoutePicker(largeSize: Bool) -> PCRoutePickerView
    func presentManualPlaylistsChooser()
}

extension NowPlayingPlayerItemViewController: NowPlayingActionsDelegate {
    /// The tint of the shelf buttons that are on. The large screen background comes from the
    /// artwork, as the podcast color does, so they're white there to always stand out.
    var activeShelfButtonTintColor: UIColor {
        usesLargeScreenStyle ? ThemeColor.playerContrast01() : PlayerColorHelper.playerHighlightColor01(for: .dark)
    }

    @objc func reloadShelfActions() {
        guard let playingEpisode = PlaybackManager.shared.currentEpisode else { return }

        let actions = Settings.playerActions()

        // don't reload the actions unless we need to
        if !lastShelfLoadState.updateRequired(shelfActions: actions, episodeUuid: playingEpisode.uuid, effectsOn: PlaybackManager.shared.effects.effectsEnabled(), sleepTimerOn: PlaybackManager.shared.isSleepTimerActive, episodeStarred: playingEpisode.keepEpisode, episodeStatus: playingEpisode.episodeStatus, videoToggleAvailable: PlaybackManager.shared.canToggleVideoRendering, videoRendering: PlaybackManager.shared.shouldRenderVideo) { return }

        // load the first 4 actions into the player, followed by an overflow icon
        playerControlsStackView.removeAllSubviews()
        smartBookmarksTipAnchor = nil
        for action in actions {
            if !action.canBePerformedOn(episode: playingEpisode) { continue }

            if !loadActionIntoShelf(action, playingEpisode: playingEpisode) { break }
        }
    }

    private func loadActionIntoShelf(_ action: PlayerAction, playingEpisode: BaseEpisode) -> Bool {
        let currentActionCount = playerControlsStackView.arrangedSubviews.count

        if Constants.Limits.maxShelfActions == currentActionCount {
            // add the overflow action
            let overflowButton = UIButton(frame: CGRect.zero)
            overflowButton.isPointerInteractionEnabled = true
            overflowButton.setImage(UIImage(named: "more"), for: .normal)
            overflowButton.imageView?.tintColor = ThemeColor.playerContrast02()
            overflowButton.addTarget(self, action: #selector(overflowTapped), for: .touchUpInside)
            overflowButton.accessibilityLabel = L10n.accessibilityMoreActions
            addToShelf(on: overflowButton)

            if smartBookmarksTipAnchor == nil {
                smartBookmarksTipAnchor = overflowButton
            }

            return false
        }

        switch action {
        case .effects:
            let effects = PlaybackManager.shared.effects

            let effectsBtn = EffectsButton(frame: CGRect.zero)
            effectsBtn.isPointerInteractionEnabled = true
            effectsBtn.effectsOn = effects.effectsEnabled()
            effectsBtn.tintColor = effectsBtn.effectsOn ? activeShelfButtonTintColor : ThemeColor.playerContrast02()
            effectsBtn.addTarget(self, action: #selector(effectsBtnTapped(_:)), for: .touchUpInside)

            addToShelf(on: effectsBtn)
        case .sleepTimer:
            let sleepBtn = SleepTimerButton(frame: CGRect.zero)
            sleepBtn.isPointerInteractionEnabled = true
            let sleepTimerActive = PlaybackManager.shared.isSleepTimerActive
            sleepBtn.tintColor = sleepTimerActive ? activeShelfButtonTintColor : ThemeColor.playerContrast02()
            sleepBtn.sleepTimerOn = sleepTimerActive
            sleepBtn.addTarget(self, action: #selector(sleepBtnTapped(_:)), for: .touchUpInside)
            sleepBtn.accessibilityLabel = sleepTimerActive ? L10n.playerAccessibilitySleepTimerOn : L10n.playerActionTitleSleepTimer
            addToShelf(on: sleepBtn)
            sleepBtn.setupAnimation()
        case .routePicker:
            let picker = sharedRoutePicker(largeSize: true)
            picker.activeTintColor = activeShelfButtonTintColor
            playerControlsStackView.addArrangedSubview(picker)
            addToShelf(on: picker)
        case .shareEpisode:
            if playingEpisode is Episode {
                let shareBtn = UIButton(frame: CGRect.zero)
                shareBtn.isPointerInteractionEnabled = true
                shareBtn.setImage(UIImage(named: action.largeIconName(episode: nil)), for: .normal)
                shareBtn.imageView?.tintColor = ThemeColor.playerContrast02()
                shareBtn.addTarget(self, action: #selector(shareTapped(_:)), for: .touchUpInside)
                shareBtn.accessibilityLabel = L10n.share

                addToShelf(on: shareBtn)
            }
        case .goToPodcast:
            let gotoPodcastBtn = UIButton(frame: CGRect.zero)
            gotoPodcastBtn.isPointerInteractionEnabled = true
            gotoPodcastBtn.imageView?.tintColor = ThemeColor.playerContrast02()
            gotoPodcastBtn.setImage(UIImage(named: action.largeIconName(episode: nil)), for: .normal)
            gotoPodcastBtn.addTarget(self, action: #selector(goToTapped(_:)), for: .touchUpInside)
            gotoPodcastBtn.accessibilityLabel = L10n.goToPodcast

            addToShelf(on: gotoPodcastBtn)
        case .chromecast:
            playerControlsStackView.addArrangedSubview(chromecastBtn)
            addToShelf(on: chromecastBtn)
        case .starEpisode:
            if playingEpisode is Episode {
                let starBtn = UIButton(frame: CGRect.zero)
                starBtn.isPointerInteractionEnabled = true
                let starImage = UIImage(named: action.largeIconName(episode: playingEpisode))
                starBtn.setImage(starImage, for: .normal)
                starBtn.accessibilityLabel = PlayerAction.starEpisode.title(episode: playingEpisode)
                starBtn.addTarget(self, action: #selector(starTapped(_:)), for: .touchUpInside)
                starBtn.imageView?.tintColor = playingEpisode.keepEpisode ? activeShelfButtonTintColor : ThemeColor.playerContrast02()

                addToShelf(on: starBtn)
            }
        case .markPlayed:
            let markPlayedBtn = UIButton(frame: CGRect.zero)
            markPlayedBtn.isPointerInteractionEnabled = true
            markPlayedBtn.imageView?.tintColor = ThemeColor.playerContrast02()
            markPlayedBtn.setImage(UIImage(named: action.largeIconName(episode: nil)), for: .normal)
            markPlayedBtn.addTarget(self, action: #selector(markPlayedTapped(_:)), for: .touchUpInside)
            markPlayedBtn.accessibilityLabel = L10n.markPlayed

            addToShelf(on: markPlayedBtn)
        case .archive:
            let archiveButton = UIButton(frame: CGRect.zero)
            archiveButton.isPointerInteractionEnabled = true
            archiveButton.imageView?.tintColor = ThemeColor.playerContrast02()
            archiveButton.setImage(UIImage(named: action.largeIconName(episode: playingEpisode)), for: .normal)
            archiveButton.addTarget(self, action: #selector(archiveTapped(_:)), for: .touchUpInside)
            archiveButton.accessibilityLabel = L10n.archive

            addToShelf(on: archiveButton)

        case .addBookmark:
            let button = UIButton(frame: CGRect.zero)
            button.isPointerInteractionEnabled = true
            button.imageView?.tintColor = ThemeColor.playerContrast02()
            button.setImage(UIImage(named: action.largeIconName(episode: playingEpisode)), for: .normal)
            button.addTarget(self, action: #selector(bookmarkTapped(_:)), for: .touchUpInside)
            button.accessibilityLabel = L10n.addBookmark

            addToShelf(on: button)
            smartBookmarksTipAnchor = button

        case .transcript:
            let button = TranscriptShelfButton(frame: CGRect.zero)
            button.isPointerInteractionEnabled = true
            button.imageView?.tintColor = ThemeColor.playerContrast02()
            button.setImage(UIImage(named: action.largeIconName(episode: playingEpisode)), for: .normal)
            button.addTarget(self, action: #selector(transcriptTapped(_:)), for: .touchUpInside)
            button.accessibilityLabel = L10n.transcript

            addToShelf(on: button)

        case .download:
            let button = UIButton(frame: CGRect.zero)
            button.isPointerInteractionEnabled = true
            button.imageView?.tintColor = ThemeColor.playerContrast02()
            button.setImage(UIImage(named: action.largeIconName(episode: playingEpisode)), for: .normal)
            button.addTarget(self, action: #selector(downloadTapped(_:)), for: .touchUpInside)
            button.accessibilityLabel = L10n.download

            addToShelf(on: button)

        case .addToPlaylist:
            let button = UIButton(frame: CGRect.zero)
            button.isPointerInteractionEnabled = true
            button.imageView?.tintColor = ThemeColor.playerContrast02()
            button.setImage(UIImage(named: action.largeIconName(episode: playingEpisode)), for: .normal)
            button.addTarget(self, action: #selector(presentManualPlaylistsChooser(_:)), for: .touchUpInside)
            button.accessibilityLabel = L10n.playlistManualEpisodeAddToPlaylist

            addToShelf(on: button)
        case .videoToggle:
            let renderingVideo = PlaybackManager.shared.shouldRenderVideo
            let button = UIButton(frame: CGRect.zero)
            button.isPointerInteractionEnabled = true
            button.imageView?.tintColor = ThemeColor.playerContrast02()
            button.setImage(UIImage(named: renderingVideo ? "video_off" : "video_on"), for: .normal)
            button.addTarget(self, action: #selector(videoToggleBtnTapped(_:)), for: .touchUpInside)
            button.accessibilityLabel = renderingVideo ? L10n.playerActionHideVideo : L10n.playerActionShowVideo

            addToShelf(on: button)
        }

        return true
    }

    // MARK: - NowPlayingActionsDelegate

    func starEpisodeTapped() {
        performStarAction()
    }

    func effectsTapped() {
        showEffectsPanel()
    }

    func sleepTimerTapped() {
        showSleepPanel()
    }

    func routePickerTapped() {
        // This is a bit hacky, but since when the button is located in the shelf, this action is not called
        // we have no way of knowing whether the picker was opened. So we're relying on the willShow delegate method
        // since we don't want to double the events up, we'll unregister the delegate while we show the
        // picker from the overflow menu, then set the delegate again after.
        routePicker.delegate = nil

        // not super happy with this solution but there doesn't appear to be a public API to pop this dialog up...
        if let routePickerButton = routePicker.subviews.first(where: { $0 is UIButton }) as? UIButton {
            routePickerButton.sendActions(for: .touchUpInside)
        }
        routePicker.delegate = self
    }

    func shareTapped() {
        shareEpisode(sender: playerControlsStackView)
    }

    func goToTapped() {
        if PlaybackManager.shared.currentEpisode is Episode {
            goToPodcast()
        } else if PlaybackManager.shared.currentEpisode is UserEpisode {
            goToFiles()
        }
    }

    func chromecastTapped() {
        googleCastTapped()
    }

    func markPlayedTapped() {
        markPlayed()
    }

    func archiveTapped() {
        if PlaybackManager.shared.currentEpisode is UserEpisode {
            delete()
        } else {
            archive()
        }
    }

    func sharedRoutePicker(largeSize: Bool) -> PCRoutePickerView {
        routePicker.removeFromSuperview()
        routePicker.setupColors()

        if largeSize {
            routePicker.layer.transform = CATransform3DMakeScale(1.3, 1.3, 1)
        } else {
            routePicker.layer.transform = CATransform3DIdentity
        }

        return routePicker
    }

    func bookmarkTapped() {
        PlaybackManager.shared.bookmark()
    }

    func transcriptTapped() {
        openTranscript()
    }

    func videoToggleTapped() {
        PlaybackManager.shared.toggleVideoRendering()
    }

    func downloadTapped() {
        guard let episode = PlaybackManager.shared.currentEpisode as? Episode else { return }

        if episode.downloaded(pathFinder: DownloadManager.shared) {
            let confirmation = OptionsPicker(title: L10n.podcastDetailsRemoveDownload)
            let yesAction = OptionAction(label: L10n.remove, icon: nil) {
                self.deleteDownloadedFile()
                Toast.show(L10n.playerEpisodeWasRemoved)
            }
            yesAction.destructive = true
            confirmation.addAction(action: yesAction)

            confirmation.present(from: self)
        } else if episode.isInDownloadProcess {
            PlaybackActionHelper.stopDownload(episodeUuid: episode.uuid)
            Toast.show(L10n.playerEpisodeDownloadCancelled)
        } else {
            PlaybackActionHelper.download(episodeUuid: episode.uuid)
            Toast.show(L10n.playerEpisodeQueuedForDownload)
        }
    }

    private func deleteDownloadedFile() {
        guard let episode = PlaybackManager.shared.currentEpisode as? Episode else { return }

        PlaybackManager.shared.removeIfPlayingOrQueued(episode: episode, fireNotification: true, userInitiated: false)
        EpisodeManager.deleteDownloadedFiles(episode: episode, userInitated: true)

        NotificationCenter.postOnMainThread(notification: Constants.Notifications.episodeDownloadStatusChanged, object: episode.uuid)
    }

    // MARK: - Player Actions
    private func presentUsingSheet(_ viewController: UIViewController, forceLarge: Bool = false) {
        if let sheetController = viewController.sheetPresentationController {
            // We create a custom detent height of a bit more than half the hosting VC to try and
            // ensure that all of the shelf content is visible in the sheet. We offer a large detent
            // as a fallback so that the user can pull the sheet up if any content is ever cut off.
            let maxWidth = sheetController.containerView?.bounds.width ?? .greatestFiniteMagnitude
            let sheetDetentHeight = sheetController.presentedViewController.view.sizeThatFits(CGSizeMake(maxWidth, .greatestFiniteMagnitude)).height
            sheetController.detents = [.custom(resolver: { _ in sheetDetentHeight })]

            // The Shelf Actions VC implements its own grabber UI.
            sheetController.prefersGrabberVisible = false
        }

        present(viewController, animated: true, completion: nil)
    }

    @objc func overflowTapped() {
        let shelfController = ShelfActionsViewController()
        shelfController.playerActionsDelegate = self

        presentUsingSheet(shelfController, forceLarge: true)
    }

    @objc private func sleepBtnTapped(_ sender: UIButton) {
        showSleepPanel()
    }

    @objc private func effectsBtnTapped(_ sender: UIButton) {
        showEffectsPanel()
    }

    @objc private func starTapped(_ sender: UIButton) {
        performStarAction(starBtn: sender)
    }

    @objc private func goToTapped(_ sender: UIButton) {
        goToTapped()
    }

    @objc private func markPlayedTapped(_ sender: UIButton) {
        markPlayed()
    }

    @objc private func archiveTapped(_ sender: UIButton) {
        archiveTapped()
    }

    @objc private func shareTapped(_ sender: UIButton) {
        shareEpisode(sender: sender)
    }

    @objc private func bookmarkTapped(_ sender: UIButton) {
        bookmarkTapped()
    }

    @objc private func transcriptTapped(_ sender: UIButton) {
        guard let transcriptButton = sender as? TranscriptShelfButton, transcriptButton.isTranscriptEnabled else {
            Toast.show(TranscriptError.notAvailable.localizedDescription)
            return
        }

        openTranscript()
    }

    @objc private func downloadTapped(_ sender: UIButton) {
        downloadTapped()
    }

    @objc private func videoToggleBtnTapped(_ sender: UIButton) {
        videoToggleTapped()
    }

    // MARK: - Sleep Timer

    @objc func sleepTimerUpdated() {
        reloadShelfActions()
    }

    // MARK: - Manual Playlists

    @objc func presentManualPlaylistsChooser(_ sender: UIButton) {
        presentManualPlaylistsChooser()
    }

    @objc func presentManualPlaylistsChooser() {
        guard let episode = PlaybackManager.shared.currentEpisode else { return }

        NavigationManager.shared.navigateTo(
            NavigationManager.manualPlaylistsChooserKey,
            data: [
                NavigationManager.manualPlaylistsChooserEpisodeKey: episode
            ]
        )
    }

    // MARK: - Actions Implementation

    private func goToFiles() {
        NavigationManager.shared.navigateTo(NavigationManager.filesPageKey, data: nil)
    }

    private func goToPodcast() {
        guard let episode = PlaybackManager.shared.currentEpisode as? Episode else { return }

        NavigationManager.shared.navigateTo(NavigationManager.podcastPageKey, data: [NavigationManager.podcastKey: episode.podcastUuid])
    }

    private func markPlayed() {
        guard let episode = PlaybackManager.shared.currentEpisode else { return }

        let alert = UIAlertController(title: L10n.playerMarkAsPlayedConfirmation, message: L10n.playerMarkAsPlayedConfirmationMessage, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: L10n.cancel, style: .cancel))
        alert.addAction(UIAlertAction(title: L10n.markPlayedShort, style: .destructive) { _ in
            EpisodeManager.markAsPlayed(episode: episode, fireNotification: true)
        })
        present(alert, animated: true)
    }

    private func delete() {
        guard let episode = PlaybackManager.shared.currentEpisode as? UserEpisode else { return }

        UserEpisodeManager.presentDeleteOptions(episode: episode, from: self)
    }

    private func archive() {
        guard let episode = PlaybackManager.shared.currentEpisode as? Episode else { return }

        let alert = UIAlertController(title: L10n.playerArchivedConfirmation, message: L10n.playerArchivedConfirmationMessage, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: L10n.cancel, style: .cancel))
        alert.addAction(UIAlertAction(title: L10n.archive, style: .destructive) { _ in
            EpisodeManager.archiveEpisode(episode: episode, fireNotification: true)
        })
        present(alert, animated: true)
    }

    private func showSleepPanel() {
        let sleepController = SleepTimerViewController()

        presentUsingSheet(sleepController)
    }

    private func showEffectsPanel() {
        let effectsController = EffectsViewController()

        presentUsingSheet(effectsController)
    }

    private func performStarAction(starBtn: UIButton? = nil) {
        guard let episode = PlaybackManager.shared.currentEpisode as? Episode else { return }

        EpisodeManager.setStarred(!episode.keepEpisode, episode: episode, updateSyncStatus: false)

        if let starBtn {
            let starImage = episode.keepEpisode ? UIImage(named: "player_star_filled") : UIImage(named: "player_star_empty")

            UIView.transition(with: starBtn, duration: Constants.Animation.defaultAnimationTime, options: .transitionCrossDissolve, animations: {
                starBtn.setImage(starImage, for: .normal)
                starBtn.imageView?.tintColor = episode.keepEpisode ? self.activeShelfButtonTintColor : ThemeColor.playerContrast02()
            }, completion: nil)
        }
    }

    private func shareEpisode(sender: UIView) {
        guard let episode = PlaybackManager.shared.currentEpisode as? Episode else { return }

        SharingModal.showModal(episode: episode, in: self)
    }

    private func shareEpisode(source: UIView, episode: Episode, fromTime: TimeInterval) {
        guard let _ = source.superview else { return }

        if fromTime == 0 {
            SharingModal.show(option: .episode(episode), in: self)
        } else {
            SharingModal.show(option: .currentPosition(episode, fromTime), in: self)
        }
    }

    // MARK: - Private Helpers

    private func addToShelf(on view: UIView) {
        playerControlsStackView.addArrangedSubview(view)
        view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            view.widthAnchor.constraint(equalToConstant: shelfIconSize),
            view.heightAnchor.constraint(equalToConstant: shelfIconSize)
        ])
    }
}

// MARK: - Smart Bookmarks tip

extension NowPlayingPlayerItemViewController {
    /// Shows the one-time tip that points at the action used to add a bookmark, for the release that introduces Smart Bookmarks.
    func showSmartBookmarksTipIfNeeded() {
        guard
            SmartBookmarksPromo.shouldShowPlayerTip,
            smartBookmarksTip == nil,
            let anchor = smartBookmarksTipAnchor,
            let episode = PlaybackManager.shared.currentEpisode,
            PlayerAction.addBookmark.canBePerformedOn(episode: episode)
        else {
            return
        }

        smartBookmarksTip = presentTip(
            title: L10n.bookmarksPlayerTipTitle,
            message: L10n.bookmarksPlayerTipMessage,
            anchor: .item(anchor),
            arrow: .down,
            idealSize: CGSize(width: 240, height: 64),
            onTap: { [weak self] in
                self?.dismissSmartBookmarksTip()
            },
            onDismiss: { [weak self] in
                self?.dismissSmartBookmarksTip()
            },
            onShow: {
                Settings.shouldShowBookmarksPlayerTip = false
            }
        )
    }

    func dismissSmartBookmarksTip() {
        guard smartBookmarksTip != nil else { return }

        Settings.shouldShowBookmarksPlayerTip = false
        smartBookmarksTip?.dismiss(animated: true) { [weak self] in
            self?.smartBookmarksTip = nil
        }
    }
}

extension NowPlayingPlayerItemViewController: @preconcurrency AVRoutePickerViewDelegate {
    func routePickerViewWillBeginPresentingRoutes(_ routePickerView: AVRoutePickerView) {

        // This prepares routing options without activating the session
        // The actual session activation happens when playback begins
        if FeatureFlag.activateAudioSessionForRoutePicker.enabled {
            AVAudioSession.sharedInstance().prepareRouteSelectionForPlayback { shouldStartPlayback, routeSelection in
                FileLog.shared.addMessage("Route selection prepared: shouldStartPlayback=\(shouldStartPlayback), type=\(routeSelection.rawValue)")
            }
        }
    }
}
