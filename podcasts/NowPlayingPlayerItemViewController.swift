import Agrume
import AVKit
import SafariServices
import UIKit
import PocketCastsUtils
import SwiftUI
import PocketCastsServer

@MainActor
class NowPlayingPlayerItemViewController: PlayerItemViewController {
    var showingCustomImage = false

    /// Low-res artwork handed over from the mini player when opening the full
    /// screen player.
    var placeholderArtwork: UIImage?

    // Detect Display Zoom (zoomed display makes UI elements appear larger).
    // Scale controls down slightly when zoomed to avoid oversized buttons.
    private var isZoomed: Bool {
        view.window?.windowScene?.screen.isDisplayZoomed ?? false
    }

    var videoViewController: VideoViewController?

    @IBOutlet var skipBackBtn: SkipButton! {
        didSet {
            skipBackBtn.skipBack = true
            skipBackBtn.accessibilityLabel = L10n.skipBack
            skipBackBtn.semanticContentAttribute = .playback
        }
    }

    @IBOutlet var skipFwdBtn: SkipButton! {
        didSet {
            skipFwdBtn.skipBack = false
            skipFwdBtn.accessibilityLabel = L10n.skipForward
            skipFwdBtn.semanticContentAttribute = .playback
            skipFwdBtn.longPressed = { [weak self] in
                self?.skipForwardLongPressed()
            }
        }
    }

    @IBOutlet var playPauseBtn: PlayPauseButton!

    @IBOutlet var playSkipStackView: UIStackView! {
        didSet {
            playSkipStackView.semanticContentAttribute = .playback
        }
    }

    @IBOutlet var episodeImage: UIImageView! {
        didSet {
            episodeImage.accessibilityLabel = L10n.accessibilityPodcastArtwork
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(imageTapped))
            tapGesture.numberOfTapsRequired = 1
            tapGesture.numberOfTouchesRequired = 1
            episodeImage.addGestureRecognizer(tapGesture)
        }
    }

    private(set) var artworkImageView: UIImageView!

    @IBOutlet var episodeName: ThemeableLabel! {
        didSet {
            episodeName.style = .playerContrast01
            episodeName.adjustsFontForContentSizeCategory = true
            episodeName.font = .font(ofSize: 18, weight: .semibold, scalingWith: .largeTitle)
        }
    }

    @IBOutlet var podcastName: ThemeableLabel! {
        didSet {
            podcastName.style = .playerContrast02
            podcastName.adjustsFontForContentSizeCategory = true
            podcastName.font = .font(ofSize: 14, weight: .medium, scalingWith: .largeTitle)

            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(podcastNameTapped))
            podcastName.addGestureRecognizer(tapGesture)

            podcastName.accessibilityTraits = .button
            podcastName.accessibilityHint = L10n.accessibilityHintPlayerNavigateToPodcastLabel
        }
    }

    @IBOutlet var chapterName: ThemeableLabel! {
        didSet {
            chapterName.style = .playerContrast01
            chapterName.adjustsFontForContentSizeCategory = true
            chapterName.font = .font(ofSize: 18, weight: .semibold, scalingWith: .largeTitle)

            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(chapterNameTapped))
            chapterName.addGestureRecognizer(tapGesture)
        }
    }

    @IBOutlet var floatingVideoView: FloatingVideoView! {
        didSet {
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(videoTapped))
            tapGesture.numberOfTapsRequired = 1
            tapGesture.numberOfTouchesRequired = 1
            floatingVideoView.addGestureRecognizer(tapGesture)

            floatingVideoView.onFullScreenTapped = { [weak self] in
                self?.showVideo(rotatesToLandscape: true)
            }
        }
    }

    // MARK: - Chapters

    @IBOutlet var chapterSkipBackBtn: UIButton! {
        didSet {
            chapterSkipBackBtn.tintColor = ThemeColor.playerContrast01()
            chapterSkipBackBtn.accessibilityLabel = L10n.siriShortcutPreviousChapter
        }
    }

    @IBOutlet var chapterSkipFwdBtn: UIButton! {
        didSet {
            chapterSkipFwdBtn.tintColor = ThemeColor.playerContrast01()
            chapterSkipFwdBtn.accessibilityLabel = L10n.siriShortcutNextChapter
        }
    }

    @IBOutlet var chapterCounter: ThemeableLabel! {
        didSet {
            chapterCounter.style = .playerContrast02
            chapterCounter.adjustsFontForContentSizeCategory = true
            chapterCounter.font = .font(ofSize: 12, weight: .semibold, scalingWith: .largeTitle)
        }
    }

    @IBOutlet var chapterTimeLeftLabel: UILabel! {
        didSet {
            chapterTimeLeftLabel.adjustsFontForContentSizeCategory = true
            chapterTimeLeftLabel.font = .font(ofSize: 11, weight: .semibold, scalingWith: .largeTitle).monospaced()
        }
    }

    @IBOutlet var chapterProgress: ProgressCircleView! {
        didSet {
            chapterProgress.lineWidth = 2
            chapterProgress.lineColor = ThemeColor.playerContrast03()
        }
    }

    @IBOutlet var chapterLink: UIView! {
        didSet {
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(chapterLinkTapped))
            chapterLink.addGestureRecognizer(tapGesture)
        }
    }

    @IBOutlet var chapterInfoView: UIView!
    @IBOutlet var episodeInfoView: UIView!

    @IBOutlet var shelfBg: ThemeableView! {
        didSet {
            shelfBg.style = .playerContrast06
        }
    }

    // MARK: - Time Slider

    @IBOutlet var timeSlider: TimeSlider! {
        didSet {
            timeSlider.accessibilityLabel = L10n.accessibilityEpisodePlayback
            timeSlider.delegate = self
        }
    }

    @IBOutlet var playerControlsStackView: UIStackView!

    @IBOutlet var timeSliderHolderView: UIView! {
        didSet {
            timeSliderHolderView.semanticContentAttribute = .playback
        }
    }

    @IBOutlet var timeElapsed: ThemeableLabel! {
        didSet {
            timeElapsed.style = .playerContrast02
            let baseFont = UIFont.monospacedDigitSystemFont(ofSize: 12, weight: UIFont.Weight.medium)
            let metrics = UIFontMetrics(forTextStyle: .largeTitle)
            timeElapsed.font = metrics.scaledFont(for: baseFont)
            timeElapsed.adjustsFontForContentSizeCategory = true
        }
    }

    @IBOutlet var timeRemaining: ThemeableLabel! {
        didSet {
            timeRemaining.style = .playerContrast02
            let baseFont = UIFont.monospacedDigitSystemFont(ofSize: 12, weight: UIFont.Weight.medium)
            let metrics = UIFontMetrics(forTextStyle: .largeTitle)
            timeRemaining.font = metrics.scaledFont(for: baseFont)
            timeRemaining.adjustsFontForContentSizeCategory = true
        }
    }

    @IBOutlet var playPauseHeightConstraint: NSLayoutConstraint!

    @IBOutlet weak var fillView: UIView!

    @IBOutlet weak var bottomControlsStackView: UIStackView!

    @IBOutlet weak var errorContainer: ThemeableView! {
        didSet {
            errorContainer.style = .playerContrast06
        }
    }

    @IBOutlet weak var errorLabel: ThemeableLabel! {
        didSet {
            errorLabel.font = .font(ofSize: 14, weight: .medium, scalingWith: .subheadline)
            errorLabel.style = .playerContrast02
        }
    }

    @IBOutlet weak var playerBottomSpacing: NSLayoutConstraint!

    @IBOutlet weak var errorBottomSpacing: NSLayoutConstraint!

    var errorAutoDismissWork: DispatchWorkItem?

    let chromecastBtn = PCAlwaysVisibleCastBtn()
    let routePicker = PCRoutePickerView(frame: CGRect.zero)

    private lazy var upNextController = UpNextViewController()

    lazy var upNextViewController: UIViewController = {
        let controller = SJUIUtils.navController(for: upNextController, iconStyle: .secondaryText01, themeOverride: upNextController.themeOverride)
        controller.modalPresentationStyle = .pageSheet

        return controller
    }()

    var lastShelfLoadState = ShelfLoadState()

    /// The shelf button the Smart Bookmarks tip points at: the bookmark button when it's on the shelf, the overflow button otherwise.
    weak var smartBookmarksTipAnchor: UIView?
    var smartBookmarksTip: UIViewController?

    override func viewDidLoad() {
        super.viewDidLoad()

        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (controller: NowPlayingPlayerItemViewController, _) in
            controller.updateSize()
        }

        registerForTraitChanges([UITraitDisplayScale.self]) { (controller: NowPlayingPlayerItemViewController, _) in
            controller.resizeControls()
        }

        setUpArtworkImageView()
        letTitleInfoGrow()
        limitShelfWidth()
        if usesLargeScreenStyle {
            playPauseBtn.useSymbolImage(pointSize: 120, scalesToFit: true)
        }

        let upNextPan = UIPanGestureRecognizer(target: self, action: #selector(panGestureRecognizerHandler(_:)))
        upNextPan.delegate = self
        view.addGestureRecognizer(upNextPan)

        chromecastBtn.inactiveTintColor = ThemeColor.playerContrast02()
        chromecastBtn.addTarget(self, action: #selector(googleCastTapped), for: .touchUpInside)
        chromecastBtn.isPointerInteractionEnabled = true

        routePicker.delegate = self

    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        showSmartBookmarksTipIfNeeded()
    }

    override func viewIsAppearing(_ animated: Bool) {
        super.viewIsAppearing(animated)

        // Layout can run before the view has a window to read Display Zoom from.
        resizeControls()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        dismissSmartBookmarksTip()
    }

    private var lastBoundsAdjustedFor = CGRect.zero

    var displayTranscript = false {
        didSet {
            toggleTranscript()
        }
    }

    /// Selects the transcript tab when it's next to Now Playing, and covers Now Playing with
    /// the transcript otherwise.
    func openTranscript() {
        if playerContainer?.showTranscriptTab() == true {
            return
        }
        displayTranscript = true
    }

    /// The parent, or, in the large screen layout, the parent of the pane it's shown in.
    private var playerContainer: PlayerContainerViewController? {
        var ancestor = parent
        while let controller = ancestor {
            if let playerContainer = controller as? PlayerContainerViewController {
                return playerContainer
            }
            ancestor = controller.parent
        }
        return nil
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        if LiquidGlass.isEnabled {
            // Render the shelf as a proper pill instead of the default rounded rectangle.
            shelfBg.layer.cornerRadius = shelfBg.bounds.height / 2
        }

        updateShelfSpacing()

        // there's some expensive operations in resizeControls,
        // so only do them if the bounds has actually changed
        if lastBoundsAdjustedFor == view.bounds { return }
        lastBoundsAdjustedFor = view.bounds

        resizeControls()
    }

    private func resizeControls() {
        let spacing: CGFloat
        if view.bounds.width <= 320 {
            spacing = 8
        } else if view.bounds.width <= 375 {
            spacing = 20
        } else {
            spacing = 30
        }

        if playerControlsStackView.spacing != spacing { playerControlsStackView.spacing = spacing }

        // Base height for play/pause. If zoomed and not showing transcript, scale down a bit.
        let baseHeight: CGFloat = displayTranscript ? 40 : (view.bounds.height > 710 ? 100 : 80)
        let scaledHeight: CGFloat = (!displayTranscript && isZoomed) ? baseHeight * 0.9 : baseHeight
        if playPauseHeightConstraint.constant != scaledHeight { playPauseHeightConstraint.constant = scaledHeight }

        // Ensure skip buttons are not too large on zoomed displays.
        // Use small size either when showing transcript or when display is zoomed.
        let skipSize: SkipButton.Size = (displayTranscript || isZoomed) ? .small : .large
        skipBackBtn.changeSize(to: skipSize)
        skipFwdBtn.changeSize(to: skipSize)

        view.layoutIfNeeded()
    }

    /// Lets the episode title and podcast name in the large screen player take the room they need
    /// at large text sizes, with some space around them, instead of overflowing their fixed height
    /// into the artwork and the scrubber.
    private func letTitleInfoGrow() {
        guard usesLargeScreenStyle,
              let titleInfoView = episodeInfoView.superview,
              let titleView = episodeInfoView.subviews.first,
              let fixedHeight = titleInfoView.constraints.first(where: { $0.firstItem === titleInfoView && $0.firstAttribute == .height && $0.secondItem == nil }) else { return }

        let preferredHeight = titleInfoView.heightAnchor.constraint(equalToConstant: fixedHeight.constant)
        preferredHeight.priority = .defaultHigh - 1
        fixedHeight.isActive = false
        NSLayoutConstraint.activate([
            preferredHeight,
            titleInfoView.heightAnchor.constraint(greaterThanOrEqualToConstant: fixedHeight.constant),
            titleView.topAnchor.constraint(greaterThanOrEqualTo: episodeInfoView.topAnchor, constant: 12)
        ])

        let compactControlsHeight = bottomControlsStackView.heightAnchor.constraint(equalToConstant: 0)
        compactControlsHeight.priority = .defaultHigh
        compactControlsHeight.isActive = true
    }

    /// Keeps the shelf in the large screen player from stretching across a wide Now Playing, as
    /// on iPad, by letting it be narrower than the edges it's pinned to. It stays centered.
    private func limitShelfWidth() {
        guard usesLargeScreenStyle,
              let shelfStackView = shelfBg.superview,
              let leading = shelfStackView.constraints.first(where: { $0.firstItem === shelfBg && $0.firstAttribute == .leading && $0.secondAttribute == .leadingMargin }),
              let trailing = shelfStackView.constraints.first(where: { $0.secondItem === shelfBg && $0.secondAttribute == .trailing && $0.firstAttribute == .trailingMargin }) else { return }

        let preferredWidth = shelfBg.widthAnchor.constraint(equalToConstant: 440)
        preferredWidth.priority = .defaultHigh
        NSLayoutConstraint.deactivate([leading, trailing])
        NSLayoutConstraint.activate([
            shelfBg.leadingAnchor.constraint(greaterThanOrEqualTo: shelfStackView.layoutMarginsGuide.leadingAnchor, constant: leading.constant),
            shelfStackView.layoutMarginsGuide.trailingAnchor.constraint(greaterThanOrEqualTo: shelfBg.trailingAnchor, constant: trailing.constant),
            preferredWidth
        ])
    }

    /// Gives each shelf button the same space on both sides in the large screen player, where the
    /// shelf is wide, instead of pushing the first and last ones to its edges.
    private func updateShelfSpacing() {
        guard usesLargeScreenStyle else { return }

        let buttons = playerControlsStackView.arrangedSubviews.filter { !$0.isHidden }
        guard !buttons.isEmpty, shelfBg.bounds.width > 0 else { return }

        let buttonsWidth = CGFloat(buttons.count) * shelfIconSize
        let shelfInset = (shelfBg.bounds.width - playerControlsStackView.bounds.width) / 2
        let buttonInset = (shelfBg.bounds.width - buttonsWidth) / CGFloat(2 * buttons.count)
        let margin = max(0, buttonInset - shelfInset)
        guard playerControlsStackView.directionalLayoutMargins.leading != margin else { return }

        playerControlsStackView.isLayoutMarginsRelativeArrangement = true
        playerControlsStackView.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 0, leading: margin, bottom: 0, trailing: margin)
    }

    private var artworkCornerRadius: CGFloat {
        LiquidGlass.isEnabled ? 16 : 8
    }

    /// Puts the artwork in an aspect-fitting inner view (so `cornerRadius` rounds
    /// the real image) and turns `episodeImage` into the reserved square slot.
    private func setUpArtworkImageView() {
        let artwork = AspectFitArtworkImageView()
        artwork.translatesAutoresizingMaskIntoConstraints = false
        artwork.contentMode = .scaleAspectFill
        artwork.clipsToBounds = true
        artwork.layer.cornerRadius = artworkCornerRadius
        artwork.isAccessibilityElement = true
        artwork.accessibilityTraits = .image
        episodeImage.addSubview(artwork)
        episodeImage.layer.cornerRadius = 0
        artworkImageView = artwork

        // Aspect-fit, centred inside the square slot.
        let fillWidth = artwork.widthAnchor.constraint(equalTo: episodeImage.widthAnchor)
        fillWidth.priority = .defaultHigh
        let fillHeight = artwork.heightAnchor.constraint(equalTo: episodeImage.heightAnchor)
        fillHeight.priority = .defaultHigh
        NSLayoutConstraint.activate([
            artwork.centerXAnchor.constraint(equalTo: episodeImage.centerXAnchor),
            artwork.centerYAnchor.constraint(equalTo: episodeImage.centerYAnchor),
            artwork.widthAnchor.constraint(lessThanOrEqualTo: episodeImage.widthAnchor),
            artwork.heightAnchor.constraint(lessThanOrEqualTo: episodeImage.heightAnchor),
            fillWidth,
            fillHeight,
        ])
    }

    override func willBeAddedToPlayer() {
        if artworkImageView.image == nil, let placeholderArtwork {
            artworkImageView.image = placeholderArtwork
            self.placeholderArtwork = nil
        }
        update(notification: nil)
        addObservers()
    }

    override func willBeRemovedFromPlayer() {
        removeAllCustomObservers()
    }

    override func themeDidChange() {
        lastShelfLoadState = ShelfLoadState()
        update(notification: nil)
    }

    var shelfIconSize: CGFloat {
        let metrics = UIFontMetrics(forTextStyle: .largeTitle)
        let iconSize = min(45, max(32, metrics.scaledValue(for: 32)))
        return iconSize
    }

    private func updateSize() {
        let iconSize = shelfIconSize
        for view in playerControlsStackView.subviews {
            view.updateSizeConstraints(to: iconSize)
        }
    }

    // MARK: - Interface Actions

    @IBAction func skipBackTapped(_ sender: Any) {
        HapticsHelper.triggerSkipBackHaptic()
        PlaybackManager.shared.skipBack()
    }

    @IBAction func playPauseTapped(_ sender: Any) {
        HapticsHelper.triggerPlayPauseHaptic()
        PlaybackManager.shared.playPause()
    }

    @IBAction func skipFwdTapped(_ sender: Any) {
        HapticsHelper.triggerSkipForwardHaptic()
        PlaybackManager.shared.skipForward()
    }

    @IBAction func chapterSkipBackTapped(_ sender: Any) {
        PlaybackManager.shared.skipToPreviousChapter()
    }

    @IBAction func chapterSkipForwardTapped(_ sender: Any) {
        PlaybackManager.shared.skipToNextChapter()
    }

    @objc private func chapterLinkTapped() {
        let chapters = PlaybackManager.shared.currentChapters
        guard let urlString = chapters.url, let url = URL(string: urlString) else { return }

            if Settings.openLinks {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            } else {
                present(SFSafariViewController(with: url), animated: true)
            }
    }

    @objc private func imageTapped() {
        guard let artwork = artworkImageView.image else { return }

        let agrume = Agrume(image: artwork, background: .blurred(.regular))
        agrume.show(from: self)
    }

    @objc private func videoTapped() {
        showVideo(rotatesToLandscape: false)
    }

    private func showVideo(rotatesToLandscape: Bool) {
        guard PlaybackManager.shared.currentEpisode != nil, presentedViewController == nil else { return }

        if PlaybackManager.shared.shouldRenderVideo {
            let videoController = VideoViewController()
            videoController.rotatesToLandscape = rotatesToLandscape
            videoController.orientationAtPresentation = view.window?.windowScene?.interfaceOrientation ?? .portrait
            videoViewController = videoController
            videoViewController?.modalPresentationStyle = .fullScreen
            if #available(iOS 18.0, *) {
                videoViewController?.preferredTransition = .zoom { [weak self] _ in
                    self?.floatingVideoView
                }
            } else {
                videoViewController?.modalTransitionStyle = .crossDissolve
            }
            videoViewController?.willAttachPlayer = { [weak self] in
                self?.floatingVideoView.player = nil
            }
            videoViewController?.willDeattachPlayer = { [weak self] in
                self?.floatingVideoView.player = PlaybackManager.shared.internalPlayerForVideoPlayback()
            }

            present(videoController, animated: true, completion: nil)
        }
    }

    @objc private func chapterNameTapped() {
        containerDelegate?.scrollToCurrentChapter()
    }

    @objc private func podcastNameTapped() {
        containerDelegate?.navigateToPodcast()
    }

    private func skipForwardLongPressed() {
        guard let episode = PlaybackManager.shared.currentEpisode else { return }

        let options = OptionsPicker(title: nil, themeOverride: .dark)

        let markPlayedOption = OptionAction(label: L10n.markPlayedShort, icon: nil) {
            EpisodeManager.markAsPlayed(episode: episode, fireNotification: true)
        }
        options.addAction(action: markPlayedOption)

        if PlaybackManager.shared.queue.upNextCount() > 0 {
            let skipToNextAction = OptionAction(label: L10n.nextEpisode, icon: nil) {
                let currentlyPlayingEpisode = PlaybackManager.shared.currentEpisode
                PlaybackManager.shared.removeIfPlayingOrQueued(episode: currentlyPlayingEpisode, fireNotification: true, userInitiated: true)
            }
            options.addAction(action: skipToNextAction)
        }

        options.present(from: self)
    }

    @objc func googleCastTapped() {
        let themeOverride = Theme.shared.activeTheme.isDark ? Theme.shared.activeTheme : .dark
        let castController = CastToViewController(themeOverride: themeOverride)
        let navController = SJUIUtils.navController(for: castController, themeOverride: themeOverride)
        navController.modalPresentationStyle = .fullScreen

        present(navController, animated: true, completion: nil)
    }

    private func toggleTranscript() {
        let isShowing = displayTranscript

        if usesLargeScreenStyle {
            skipBackBtn.prepareForAnimateTransitionReplacingAnimation()
            skipFwdBtn.prepareForAnimateTransitionReplacingAnimation()
        } else {
            skipBackBtn.prepareForAnimateTransition(withBackground: view.backgroundColor)
            skipFwdBtn.prepareForAnimateTransition(withBackground: view.backgroundColor)
        }
        playPauseBtn.prepareForAnimateTransition()

        playerContainer?.transcriptContainerView.layer.opacity = isShowing ? 0 : 1

        episodeImage.layer.opacity = 1

        if isShowing {
            playerContainer?.showTranscript()
        }

        UIView.animate(springDuration: 0.35, bounce: 0, animations: { [weak self] in
            guard let self else { return }

            // Hide/show shelf
            shelfBg.isHidden = isShowing
            shelfBg.layer.opacity = isShowing ? 0 : 1

            // Show/hide transcript container view
            playerContainer?.transcriptContainerView.isHidden = false
            playerContainer?.transcriptContainerView.layer.opacity = isShowing ? 1 : 0

            // Change the stack view that contains the player button
            bottomControlsStackView.distribution = isShowing ? .fill : .equalSpacing
            bottomControlsStackView.spacing = isShowing ? 10 : 30

            // Display/hide the view that will fill the empty space
            fillView.isHidden = !isShowing

            // Change skip back and forward size (also keep small on zoomed displays)
            let skipButtonSize: SkipButton.Size = (isShowing || isZoomed) ? .small : .large
            skipBackBtn.changeSize(to: skipButtonSize)
            skipFwdBtn.changeSize(to: skipButtonSize)
            skipBackBtn.layoutIfNeeded()
            skipFwdBtn.layoutIfNeeded()

            // Ask parent VC to hide/show tabs
            playerContainer?.scrollView(isEnabled: !isShowing)

            resizeControls()
        }, completion: { [weak self] _ in
            guard let self else { return }

            playerContainer?.transcriptContainerView.isHidden = isShowing ? false : true

            if !isShowing {
                playerContainer?.hideTranscript()
            } else {
                episodeImage.layer.opacity = 0
            }

            playPauseBtn.finishedTransition()
            skipBackBtn.finishedTransition()
            skipFwdBtn.finishedTransition()
        })
    }

}

/// A `UIImageView` that constrains itself to its image's aspect ratio, so when
/// aspect-fit in a container its `cornerRadius` rounds the visible image (no mask).
final class AspectFitArtworkImageView: UIImageView {
    private var aspectRatioConstraint: NSLayoutConstraint?

    override var image: UIImage? {
        didSet { updateAspectRatioConstraint() }
    }

    private func updateAspectRatioConstraint() {
        aspectRatioConstraint?.isActive = false
        guard let size = image?.size, size.width > 0, size.height > 0 else {
            aspectRatioConstraint = nil
            return
        }
        let constraint = widthAnchor.constraint(equalTo: heightAnchor, multiplier: size.width / size.height)
        constraint.isActive = true
        aspectRatioConstraint = constraint
    }
}
