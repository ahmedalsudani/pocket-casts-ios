import UIKit
import Combine
import PocketCastsDataModel
import PocketCastsServer
import PocketCastsUtils

class TranscriptViewController: PlayerItemViewController {
    private let playbackManager: TranscriptPlaybackManaging
    private var transcript: TranscriptModel?

    private var canScrollToDismiss = true

    private var isSearching = false {
        didSet {
            guard isSearching != oldValue else { return }
            restoreControlButtonsLayout()
        }
    }
    private var searchIndicesResult: [Int] = []
    private var currentSearchIndex = 0
    private var searchTerm: String?

    private let debounce = Debounce(delay: Constants.defaultDebounceTime)

    private var kmpSearch: KMPSearch?

    private var transcriptManager: TranscriptManager?

    var playButtonTapped: ((Bool) -> Void)?

    /// Set before the view loads when the transcript is a tab of the large screen player, which
    /// has nothing to close. Its buttons float over the bottom of the transcript instead.
    var isPlayerTab = false

    /// Shown from Episode Details rather than the player, which takes the app's theme instead of the player's colors
    private let showFromEpisode: Bool

    init(playbackManager: TranscriptPlaybackManaging, showFromEpisode: Bool = false) {
        self.playbackManager = playbackManager
        self.showFromEpisode = showFromEpisode
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        parent?.view.overrideUserInterfaceStyle = .unspecified
        dismissSearch()
        resetSearch()
    }

    override var canBecomeFirstResponder: Bool {
        true
    }

    private func setupViews() {
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self, UITraitHorizontalSizeClass.self]) { (controller: TranscriptViewController, previousTraitCollection: UITraitCollection) in
            if controller.traitCollection.preferredContentSizeCategory != previousTraitCollection.preferredContentSizeCategory {
                controller.refreshText()
                controller.refreshError()
                controller.refreshActionButtons()
            }
            controller.updateTextMargins()
        }

        let topMargin = showFromEpisode ? 8.0 : 0.0

        view.addSubview(transcriptView)
        view.keyboardLayoutGuide.usesBottomSafeArea = showFromEpisode
        NSLayoutConstraint.activate(
            [
                transcriptView.topAnchor.constraint(equalTo: view.topAnchor, constant: topMargin),
                transcriptView.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor),
                transcriptView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                transcriptView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
            ]
        )

        updateTextMargins()
        transcriptView.scrollIndicatorInsets = .init(top: 0.75 * Sizes.topGradientHeight, left: 0, bottom: bottomContainerInset, right: 0)

        view.addSubview(activityIndicatorView)
        NSLayoutConstraint.activate(
            [
                activityIndicatorView.centerXAnchor.constraint(equalTo: view.centerXAnchor, constant: -Sizes.activityIndicatorSize / 2),
                activityIndicatorView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -Sizes.activityIndicatorSize / 2)
            ]
        )

        view.addSubview(errorView)
        NSLayoutConstraint.activate(
            [
                errorView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                errorView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
                errorView.widthAnchor.constraint(equalTo: view.readableContentGuide.widthAnchor, constant: -Sizes.textMargin)
            ]
        )

        view.addSubview(topGradient)
        topGradient.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate(
            [
                topGradient.topAnchor.constraint(equalTo: view.topAnchor, constant: topMargin),
                topGradient.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                topGradient.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                topGradient.heightAnchor.constraint(equalToConstant: Sizes.topGradientHeight)
            ]
        )

        view.addSubview(bottomGradient)
        bottomGradient.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate(
            [
                bottomGradient.bottomAnchor.constraint(equalTo: showFromEpisode ? view.safeAreaLayoutGuide.bottomAnchor : view.bottomAnchor),
                bottomGradient.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                bottomGradient.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                bottomGradient.heightAnchor.constraint(equalToConstant: Sizes.bottomGradientHeight)
            ]
        )

        view.addSubview(hiddenTextView)

        if !isPlayerTab {
            stackView.addArrangedSubview(closeButton)
            stackView.addArrangedSubview(UIView())
        }

        shareButton.isHidden = !FeatureFlag.shareTranscripts.enabled
        stackView.addArrangedSubview(shareButton)

        playButton.isHidden = !showFromEpisode
        stackView.addArrangedSubview(playButton)

        stackView.addArrangedSubview(searchButton)

        cancelButton.isHidden = true
        stackView.addArrangedSubview(cancelButton)

        view.addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        if isPlayerTab {
            let safeAreaBottomConstraint = stackView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -Sizes.floatingButtonsBottomMargin)
            safeAreaBottomConstraint.priority = .defaultHigh
            NSLayoutConstraint.activate([
                safeAreaBottomConstraint,
                stackView.bottomAnchor.constraint(lessThanOrEqualTo: view.keyboardLayoutGuide.topAnchor, constant: -Sizes.floatingButtonsBottomMargin),
                stackView.trailingAnchor.constraint(equalTo: view.readableContentGuide.trailingAnchor, constant: -Sizes.textMargin)
            ])
        } else {
            NSLayoutConstraint.activate([
                stackView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: topMargin),
                stackView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 12),
                stackView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16)
            ])
        }

        closeButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            closeButton.heightAnchor.constraint(equalToConstant: 44),
            closeButton.widthAnchor.constraint(equalToConstant: 44)
        ])
    }

    // Only return the searchView as the input acessory view
    // if search has been enabled.
    // This prevents the input acessory view from appearing
    // when selecting text
    override var inputAccessoryView: UIView? {
        isSearching ? searchView : nil
    }

    lazy var searchView: TranscriptSearchAccessoryView = {
        let view = TranscriptSearchAccessoryView()
        view.delegate = self
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    @objc private func displaySearch() {
        isSearching = true

        // Keep the inputAccessoryView dark
        parent?.view.overrideUserInterfaceStyle = .dark

        hiddenTextView.becomeFirstResponder()

        // Move focus to the textView on the input accessory view
        searchView.textField.becomeFirstResponder()
        updateNumberOfResults()
    }

    @objc private func playEpisode() {
        playButton.buttonState = playbackManager.isPlayingEpisode ? .play : .pause
        playButtonTapped?(playbackManager.isPlayingEpisode)
    }

    @objc private func shareEpisode() {
        guard let transcript else { return }

        let transcriptText = transcript.attributedText.string
        let activityViewController = UIActivityViewController(activityItems: [transcriptText], applicationActivities: nil)

        if let popover = activityViewController.popoverPresentationController {
            popover.sourceView = shareButton
            popover.sourceRect = shareButton.bounds
        }

        present(activityViewController, animated: true)
    }

    private func dismissSearch() {
        isSearching = false

        searchView.textField.resignFirstResponder()

        resignFirstResponder()
    }

    @objc private func cancelSearch() {
        dismissSearch()
        resetSearch()
        searchView.removeFromSuperview()
    }

    private lazy var transcriptView: UITextView = {
        let textView = UITextView(usingTextLayoutManager: false)
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.font = .systemFont(ofSize: 16)
        textView.isEditable = false
        textView.showsVerticalScrollIndicator = true
        textView.inputAccessoryView = nil
        return textView
    }()

    private lazy var activityIndicatorView: AngularActivityIndicator = {
        let activityIndicatorView = AngularActivityIndicator(size: CGSize(width: Sizes.activityIndicatorSize, height: Sizes.activityIndicatorSize), lineWidth: 2.0, duration: 1.0)
        activityIndicatorView.color = ThemeColor.playerContrast02()
        activityIndicatorView.hidesWhenStopped = true
        activityIndicatorView.translatesAutoresizingMaskIntoConstraints = false
        return activityIndicatorView
    }()

    private lazy var errorView: TranscriptErrorView = {
        TranscriptErrorView(source: showFromEpisode ? .episode : .player) { [weak self] in
            self?.retryLoad()
        }
    }()

    private lazy var closeButton: TintableImageButton! = {
        let closeButton = TintableImageButton()
        closeButton.setImage(UIImage(named: "close"), for: .normal)
        closeButton.tintColor = showFromEpisode ? ThemeColor.primaryInteractive01() : ThemeColor.primaryIcon02()
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        return closeButton
    }()

    private lazy var searchButton: RoundButton = {
        let titleColor = showFromEpisode ? ThemeColor.primaryInteractive01() : .white
        let tintColor = showFromEpisode ? ThemeColor.primaryInteractive01().withAlphaComponent(0.1) : .white.withAlphaComponent(0.2)

        var configuration = UIButton.Configuration.filled()
        configuration.contentInsets = .init(top: 4, leading: 12, bottom: 4, trailing: 12)
        configuration.baseForegroundColor = titleColor
        configuration.baseBackgroundColor = tintColor

        let searchButton = RoundButton(type: .system)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.font(with: .callout, maxSizeCategory: .extraExtraExtraLarge)
        ]
        searchButton.setAttributedTitle(NSAttributedString(string: L10n.search, attributes: attributes), for: .normal)
        searchButton.addTarget(self, action: #selector(displaySearch), for: .touchUpInside)
        searchButton.setTitleColor(titleColor, for: .normal)
        searchButton.tintColor = tintColor
        searchButton.layer.masksToBounds = true
        searchButton.configuration = configuration
        searchButton.titleLabel?.adjustsFontForContentSizeCategory = false
        return searchButton
    }()

    private lazy var playButton: RoundPlayPauseButton = {
        let playButton = RoundPlayPauseButton.makeButton(playbackManager: playbackManager)
        playButton.addTarget(self, action: #selector(playEpisode), for: .touchUpInside)
        playButton.titleLabel?.adjustsFontForContentSizeCategory = false
        return playButton
    }()

    private lazy var shareButton: RoundButton = {
        let titleColor = showFromEpisode ? ThemeColor.primaryInteractive01() : .white
        let tintColor = showFromEpisode ? ThemeColor.primaryInteractive01().withAlphaComponent(0.1) : .white.withAlphaComponent(0.2)

        var configuration = UIButton.Configuration.filled()
        configuration.contentInsets = .init(top: 4, leading: 12, bottom: 4, trailing: 12)
        configuration.baseForegroundColor = titleColor
        configuration.baseBackgroundColor = tintColor

        let shareButton = RoundButton(type: .system)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.font(with: .callout, maxSizeCategory: .extraExtraExtraLarge)
        ]
        shareButton.setAttributedTitle(NSAttributedString(string: L10n.share, attributes: attributes), for: .normal)
        shareButton.addTarget(self, action: #selector(shareEpisode), for: .touchUpInside)
        shareButton.setTitleColor(titleColor, for: .normal)
        shareButton.tintColor = tintColor
        shareButton.layer.masksToBounds = true
        shareButton.configuration = configuration
        shareButton.titleLabel?.adjustsFontForContentSizeCategory = false
        return shareButton
    }()

    private lazy var cancelButton: RoundButton = {
        let titleColor = showFromEpisode ? ThemeColor.primaryInteractive01() : .white
        let tintColor = showFromEpisode ? ThemeColor.primaryInteractive01().withAlphaComponent(0.1) : .white.withAlphaComponent(0.2)

        var configuration = UIButton.Configuration.filled()
        configuration.contentInsets = .init(top: 4, leading: 12, bottom: 4, trailing: 12)
        configuration.baseForegroundColor = titleColor
        configuration.baseBackgroundColor = tintColor

        let cancelButton = RoundButton(type: .system)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.font(with: .callout, maxSizeCategory: .extraExtraExtraLarge)
        ]
        cancelButton.setAttributedTitle(NSAttributedString(string: L10n.cancel, attributes: attributes), for: .normal)
        cancelButton.addTarget(self, action: #selector(cancelSearch), for: .touchUpInside)
        cancelButton.setTitleColor(titleColor, for: .normal)
        cancelButton.tintColor = tintColor
        cancelButton.layer.masksToBounds = true
        cancelButton.configuration = configuration
        cancelButton.titleLabel?.adjustsFontForContentSizeCategory = false
        return cancelButton
    }()

    private lazy var hiddenTextView: UITextField = {
        let textView = UITextField()
        textView.layer.opacity = 0
        return textView
    }()

    private lazy var stackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.spacing = 8
        return stackView
    }()

    private lazy var topGradient: GradientView = {
        GradientView(firstColor: Colors.gradientColor, secondColor: Colors.gradientColor.withAlphaComponent(0))
    }()

    private lazy var bottomGradient: GradientView = {
        GradientView(firstColor: Colors.gradientColor.withAlphaComponent(0), secondColor: Colors.gradientColor)
    }()

    var bottomContainerInset: CGFloat {
        // A tab's transcript ends above the buttons floating over it.
        if isPlayerTab {
            return view.safeAreaInsets.bottom + Sizes.floatingButtonsBottomMargin + stackView.bounds.height + Sizes.floatingButtonsMargin
        }
        return 0.7 * Sizes.bottomGradientHeight
    }

    override func willBeAddedToPlayer() {
        updateColors()
        loadTranscript()
        addObservers()
        transcriptView.delegate = self
    }

    override func willBeRemovedFromPlayer() {
        removeAllCustomObservers()
    }

    override func themeDidChange() {
        updateColors()
    }

    private func updateColors() {
        let primaryColor =  showFromEpisode ? ThemeColor.primaryUi01() : PlayerColorHelper.playerBackgroundColor01()
        let secondaryColor =  showFromEpisode ? ThemeColor.primaryText01() : ThemeColor.playerContrast02()
        let activityIndicatorViewColor: UIColor = showFromEpisode ? ThemeColor.primaryIcon02() : ThemeColor.playerContrast02()
        let activityIndicatorViewStyle: UIScrollView.IndicatorStyle = showFromEpisode ? (Theme.shared.activeTheme.isDark ? .white : .black) : .white

        let backgroundColor = usesLargeScreenStyle ? .clear : primaryColor
        view.backgroundColor = backgroundColor
        transcriptView.backgroundColor = backgroundColor
        transcriptView.textColor = secondaryColor
        transcriptView.indicatorStyle = activityIndicatorViewStyle
        activityIndicatorView.color = activityIndicatorViewColor
        updateGradientColors()
    }

    private func updateGradientColors() {
        let gradientColor = showFromEpisode ? ThemeColor.primaryUi01() : Colors.gradientColor
        topGradient.updateColors(firstColor: gradientColor, secondColor: gradientColor.withAlphaComponent(0))
        bottomGradient.updateColors(firstColor: gradientColor.withAlphaComponent(0), secondColor: gradientColor)
        if usesLargeScreenStyle {
            topGradient.isHidden = true
            bottomGradient.isHidden = true
        }
    }

    private lazy var textFadeMask: CAGradientLayer = {
        let mask = CAGradientLayer()
        mask.colors = [UIColor.clear.cgColor, UIColor.black.cgColor, UIColor.black.cgColor, UIColor.clear.cgColor, UIColor.clear.cgColor]
        return mask
    }()

    /// Over the large screen player background, the text fades out where the (hidden) gradients
    /// are with a mask instead, so it doesn't need a solid background.
    private func updateTextFadeMask() {
        let height = transcriptView.bounds.height
        guard usesLargeScreenStyle, height > 0 else { return }

        let topFade = max(0, topGradient.frame.maxY - transcriptView.frame.minY)
        // A tab's transcript fades out under the buttons floating over it.
        let bottomFadeEnd = (isPlayerTab ? stackView.frame.maxY : bottomGradient.frame.maxY) - transcriptView.frame.minY
        let bottomFadeStart = isPlayerTab
            ? stackView.frame.minY - Sizes.floatingButtonsMargin - transcriptView.frame.minY
            : bottomFadeEnd - bottomGradient.frame.height

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        textFadeMask.frame = transcriptView.bounds
        textFadeMask.locations = [
            0,
            NSNumber(value: min(topFade / height, 0.5)),
            NSNumber(value: min(max(bottomFadeStart / height, 0.5), 1)),
            NSNumber(value: min(max(bottomFadeEnd / height, 0.5), 1)),
            1
        ]
        CATransaction.commit()

        if transcriptView.layer.mask !== textFadeMask {
            transcriptView.layer.mask = textFadeMask
        }
    }

    @objc private func update() {
        updateColors()
        resetKmp()
        dismissSearch()
        resetSearch()
        loadTranscript()
    }

    @objc private func closeTapped() {
        containerDelegate?.dismissTranscript()
    }

    private func setupLoadingState() {
        transcriptView.isHidden = true
        restoreControlButtonsLayout()
        setControlButtonsVisible(false)
        errorView.isHidden = true
        activityIndicatorView.startAnimating()
    }

    private func setupShowTranscriptState() {
        transcriptView.isHidden = false
        setControlButtonsVisible(true)
        errorView.isHidden = true
        activityIndicatorView.stopAnimating()
    }

    private func setControlButtonsVisible(_ visible: Bool) {
        let buttons: [UIButton] = [searchButton, shareButton, playButton]
        buttons.forEach { setControlButton($0, visible: visible) }
    }

    private func setControlButton(_ button: UIButton, visible: Bool) {
        guard !button.isHidden else { return }
        button.alpha = visible ? 1 : 0
        button.isUserInteractionEnabled = visible
    }

    private func restoreControlButtonsLayout() {
        shareButton.isHidden = !FeatureFlag.shareTranscripts.enabled || isSearching
        searchButton.isHidden = isSearching
        cancelButton.isHidden = !isSearching
    }

    private var currentEpisodeUUID: String?

    private func loadTranscript() {
        guard let episodeUUID = playbackManager.episodeUUID, let podcastUUID = playbackManager.podcastUUID else {
            return
        }

        let shouldResetPosition = currentEpisodeUUID != episodeUUID
        currentEpisodeUUID = episodeUUID

        transcriptManager = TranscriptManager(episodeUUID: episodeUUID, podcastUUID: podcastUUID)

        setupLoadingState()

        Task.detached { [weak self, transcriptManager] in
            guard let self, let transcriptManager else {
                return
            }

            do {
                let transcript = try await transcriptManager.loadTranscript()
                await MainActor.run {
                    if self.isPlayerTab {
                        self.stackView.alpha = 1
                    }
                }
                await show(transcript: transcript, resetPosition: shouldResetPosition)
            } catch {
                await show(error: error)
            }
        }
    }

    private func retryLoad() {
        errorView.isHidden = true
        loadTranscript()
    }

    private func resetSearch() {
        searchIndicesResult = []
        currentSearchIndex = 0
        searchView.textField.text = ""
        searchTerm = nil
        updateNumberOfResults()
        refreshText()
    }

    private func resetKmp() {
        kmpSearch = nil
    }

    private func refreshActionButtons() {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.font(with: .callout, maxSizeCategory: .extraExtraExtraLarge)
        ]
        searchButton.setAttributedTitle(NSAttributedString(string: L10n.search, attributes: attributes), for: .normal)
        shareButton.setAttributedTitle(NSAttributedString(string: L10n.share, attributes: attributes), for: .normal)
        cancelButton.setAttributedTitle(NSAttributedString(string: L10n.cancel, attributes: attributes), for: .normal)
        playButton.updateSize()
    }

    override public func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateTextMargins()
        updateTextFadeMask()
    }

    private func updateTextMargins() {
        let readableFrame = view.readableContentGuide.layoutFrame
        guard !readableFrame.isEmpty else { return }
        var leftMargin = readableFrame.minX + Sizes.textMargin
        var rightMargin = view.bounds.maxX - readableFrame.maxX + Sizes.textMargin
        if isPlayerTab {
            let margin = PlayerTabsView.largeScreenTitleInset - transcriptView.textContainer.lineFragmentPadding
            leftMargin = margin
            rightMargin = margin
        }
        let topInset = 0.75 * Sizes.topGradientHeight
        transcriptView.textContainerInset = .init(top: topInset, left: leftMargin, bottom: bottomContainerInset, right: rightMargin)
        if isPlayerTab {
            transcriptView.verticalScrollIndicatorInsets.bottom = bottomContainerInset
        }
    }

    @MainActor
    private func refreshError() {
        errorView.setTextAttributes(makeStyle(alignment: .center))
    }

    @MainActor
    private func refreshText() {
        guard let transcript else {
            return
        }
        transcriptView.attributedText = styleText(transcript: transcript)
    }

    private func show(transcript: TranscriptModel, resetPosition: Bool) {
        setupShowTranscriptState()
        self.transcript = transcript
        transcriptView.attributedText = styleText(transcript: transcript)
        if resetPosition {
            transcriptView.setContentOffset(.zero, animated: false)
        }
    }

    private func makeStyle(alignment: NSTextAlignment = .natural) -> [NSAttributedString.Key: Any] {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineHeightMultiple = 1.2
        paragraphStyle.paragraphSpacing = 10
        paragraphStyle.lineBreakMode = .byWordWrapping
        paragraphStyle.alignment = alignment

        // The large screen player limits the text size with the view's maximum content size category.
        let traits = view.maximumContentSizeCategory == nil ? nil : transcriptView.traitCollection
        var standardFont = UIFont.preferredFont(forTextStyle: .body, compatibleWith: traits)

        if let descriptor = UIFontDescriptor.preferredFontDescriptor(
          withTextStyle: .body, compatibleWith: traits)
          .withDesign(.serif) {
            standardFont =  UIFont(descriptor: descriptor, size: 0)
        }

        let normalStyle: [NSAttributedString.Key: Any] = [
            .paragraphStyle: paragraphStyle,
            .font: standardFont,
            .foregroundColor: showFromEpisode ? ThemeColor.primaryText01() : ThemeColor.playerContrast02()
        ]

        return normalStyle
    }

    private func styleText(transcript: TranscriptModel) -> NSAttributedString {
        let formattedText = NSMutableAttributedString(attributedString: transcript.attributedText)
        formattedText.beginEditing()
        let normalStyle = makeStyle()

        let fullLength = NSRange(location: 0, length: formattedText.length)
        formattedText.addAttributes(normalStyle, range: fullLength)

        let speakerFont = UIFont.font(ofSize: 12, scalingWith: .footnote, maxSizeCategory: view.maximumContentSizeCategory ?? .accessibilityExtraExtraExtraLarge)
        formattedText.enumerateAttribute(.transcriptSpeaker, in: fullLength, options: [.reverse, .longestEffectiveRangeNotRequired]) { value, range, _ in
            if value == nil {
                return
            }
            formattedText.addAttribute(.font, value: speakerFont, range: range)
        }

        if let searchTerm {
            let length = formattedText.length
            let searchTermLength = searchTerm.count
            searchIndicesResult.enumerated().forEach { index, indice in
                if indice + searchTermLength <= length {
                    let backgroundColor = showFromEpisode ? ThemeColor.primaryText01().withAlphaComponent(index == currentSearchIndex ? 1 : 0.6) : .white.withAlphaComponent(index == currentSearchIndex ? 1 : 0.4)
                    let highlightStyle: [NSAttributedString.Key: Any] = [
                        .backgroundColor: backgroundColor,
                        .foregroundColor: showFromEpisode ? ThemeColor.primaryUi01() : index == currentSearchIndex ? UIColor.black : ThemeColor.playerContrast01()
                    ]

                    formattedText.addAttributes(highlightStyle, range: NSRange(location: indice, length: searchTermLength))
                }
            }
        }
        formattedText.endEditing()
        return formattedText
    }

    private func show(error: Error) {
        activityIndicatorView.stopAnimating()
        // Collapse the transcript-only controls so the play button sits at the trailing edge.
        shareButton.isHidden = true
        searchButton.isHidden = true
        setControlButton(playButton, visible: true)
        var message = L10n.transcriptErrorFailedToLoad
        if let transcriptError = error as? TranscriptError {
            message = transcriptError.localizedDescription
        }
        errorView.isHidden = false
        errorView.setMessage(message, attributes: makeStyle(alignment: .center))
    }

    private func addObservers() {
        if !showFromEpisode {
            addCustomObserver(Constants.Notifications.playbackTrackChanged, selector: #selector(update))
        }
    }

    // MARK: - Search

    func performSearch(_ term: String) {
        Task {
            findOccurrences(of: term)
            updateNumberOfResults()
            refreshText()
            scrollToFirstResult()
        }
    }

    func findOccurrences(of term: String) {
        guard let transcriptText = transcript?.attributedText.string,
              !term.isEmpty else {
            resetSearch()
            return
        }

        if kmpSearch == nil {
            kmpSearch = KMPSearch(text: transcriptText)
        }
        searchIndicesResult = kmpSearch?.search(for: term) ?? []
        currentSearchIndex = 0
        searchTerm = term
    }

    @MainActor
    func updateNumberOfResults() {
        if searchTerm == nil {
            searchView.updateLabel("")
            searchView.enableUpDownButtons(false)
            return
        }

        if searchIndicesResult.isEmpty {
            searchView.updateLabel("0")
            searchView.enableUpDownButtons(false)
            return
        }

        searchView.enableUpDownButtons(true)
        searchView.updateLabel(L10n.searchResults(currentSearchIndex + 1, searchIndicesResult.count))
    }

    func scrollToFirstResult() {
        guard let searchTerm,
              let firstResultRange = searchIndicesResult.first.map({ NSRange(location: $0, length: searchTerm.count)}) else {
            return
        }
        transcriptView.scrollToRange(firstResultRange)
    }

    // MARK: - Constants

    private enum Sizes {
        static let topGradientHeight: CGFloat = 60
        static let bottomGradientHeight: CGFloat = 60
        static let activityIndicatorSize: CGFloat = 30
        static let textMargin: CGFloat = 8
        static let floatingButtonsMargin: CGFloat = 16
        static let floatingButtonsBottomMargin: CGFloat = 4
    }

    private enum Colors {
        static var gradientColor: UIColor {
            PlayerColorHelper.playerBackgroundColor01()
        }
    }
}

extension TranscriptViewController: UIScrollViewDelegate {

    // Only allow scroll to dismiss if scrolling bottom from the top
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if canScrollToDismiss {
            scrollViewHandler?.scrollViewDidScroll?(scrollView)
        }
        updateTextFadeMask()
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        canScrollToDismiss = scrollView.contentOffset.y == 0
    }
}

extension TranscriptViewController: UITextViewDelegate {
    func textView(_ textView: UITextView, editMenuForTextIn range: NSRange, suggestedActions: [UIMenuElement]) -> UIMenu? {
        guard let bookmarkAction = makeBookmarkAction(for: range) else { return nil }

        // Leads the menu: bookmarking is what the transcript is selected for, and the system
        // actions run several pages deep on a phone
        return UIMenu(children: [bookmarkAction] + suggestedActions)
    }
}

// MARK: - Bookmarking a selection

private extension TranscriptViewController {
    /// The "Bookmark" action to offer alongside the selection's system actions, or nil when
    /// this selection can't be bookmarked.
    func makeBookmarkAction(for range: NSRange) -> UIAction? {
        guard range.length > 0,
              let transcript,
              let episode = playbackManager.episodeUUID.flatMap({ DataManager.shared.findBaseEpisode(uuid: $0) }),
              let time = transcript.cue(atCharacterIndex: range.location)?.startTime else {
            return nil
        }

        return UIAction(title: L10n.transcriptBookmarkSelection, image: UIImage(systemName: "bookmark")) { [weak self] _ in
            self?.addBookmark(at: time, for: episode, selection: range, in: transcript)
        }
    }

    /// Bookmarks the moment the selection starts at, which is where the cue holding its first character begins.
    func addBookmark(at time: TimeInterval, for episode: BaseEpisode, selection: NSRange, in transcript: TranscriptModel) {
        let manager = PlaybackManager.shared.bookmarkManager

        // The passage is only read by the Smart Bookmarks path, so it's stored on the same terms
        let selectedText = BookmarkManager.isTitleSuggestionEnabled
            ? BookmarkTranscriptSnippetExtractor.text(in: selection, of: transcript.attributedText)
            : ""
        let passage = selectedText.isEmpty ? nil : BookmarkUpdateParameters.Passage(text: selectedText, location: selection.location)

        // Asked before adding, because `add` hands back the bookmark that's already there when
        // this moment has one — the sheet then edits that one instead of titling a new one
        let isNew = manager.dataManager.existingBookmark(forEpisode: episode.uuid, time: time) == nil

        guard let bookmark = manager.add(to: episode,
                                         at: time,
                                         passage: passage,
                                         fromTranscript: true) else { return }

        // Dropping the selection takes the menu with it, so the transcript is readable again
        // behind the edit sheet
        transcriptView.selectedRange = NSRange(location: selection.location, length: 0)

        showBookmarkEdit(bookmark, isNew: isNew, manager: manager)
    }

    /// The transcript titles its own bookmarks rather than leaving it to the player's bookmarks
    /// tab, which can't present over a transcript opened from Episode Details and isn't there at
    /// all until the full screen player has been opened.
    func showBookmarkEdit(_ bookmark: Bookmark, isNew: Bool, manager: BookmarkManager) {
        let controller = BookmarkEditTitleViewController(manager: manager,
                                                        bookmark: bookmark,
                                                        state: isNew ? .adding : .updating,
                                                        style: showFromEpisode ? .themed : .player) { [weak self] outcome in
            self?.handleBookmarkEditDismissed(bookmark, isNew: isNew, manager: manager, outcome: outcome)
        }

        present(controller, animated: true)
    }

    func handleBookmarkEditDismissed(_ bookmark: Bookmark, isNew: Bool, manager: BookmarkManager, outcome: BookmarkEditOutcome) {
        // Only a bookmark this selection just made is the sheet's to take back
        guard isNew else { return }

        switch outcome {
        case .cancelled:
            Task { await manager.remove([bookmark]) }

        case .saved(let title):
            let message = title == L10n.bookmarkDefaultTitle ? L10n.bookmarkAdded : L10n.bookmarkAddedNotification(title)

            // Only the player has a bookmarks tab to send them to
            let actions: [Toast.Action]? = showFromEpisode ? nil : [
                .init(title: L10n.bookmarkAddedButtonTitle) { [weak self] in
                    self?.containerDelegate?.dismissTranscript()
                    self?.containerDelegate?.scrollToBookmarks()
                }
            ]

            Toast.show(message, actions: actions, theme: .playerTheme)
        }
    }
}

extension TranscriptViewController: TranscriptSearchAccessoryViewDelegate {
    func searchButtonTapped() {
        becomeFirstResponder()
    }

    func search(_ term: String) {
        if term.isEmpty {
            debounce.cancel()
            resetSearch()
            return
        }

        debounce.call { [weak self] in
            self?.performSearch(term)
        }
    }

    func previousMatch() {
        updateCurrentSearchIndex(decrement: true)
        processMatch()
    }

    func nextMatch() {
        updateCurrentSearchIndex(decrement: false)
        processMatch()
    }

    private func updateCurrentSearchIndex(decrement: Bool) {
        if decrement {
            currentSearchIndex = (currentSearchIndex - 1 < 0) ? searchIndicesResult.count - 1 : currentSearchIndex - 1
        } else {
            currentSearchIndex = (currentSearchIndex + 1 >= searchIndicesResult.count) ? 0 : currentSearchIndex + 1
        }
    }

    private func processMatch() {
        if searchIndicesResult.isEmpty {
            return
        }

        updateNumberOfResults()
        refreshText()
        transcriptView.scrollToRange(.init(location: searchIndicesResult[currentSearchIndex], length: searchTerm?.count ?? 0))
    }
}

class RoundButton: UIButton {
    override func layoutSubviews() {
        super.layoutSubviews()

        layer.cornerRadius = bounds.height / 2
    }
}

fileprivate class RoundPlayPauseButton: RoundButton {
    private var cancellables = Set<AnyCancellable>()
    private var playbackManager: TranscriptPlaybackManaging?

    enum ButtonState {
        case play
        case pause

        var imageName: String {
            switch self {
            case .play:
                return "play.fill"
            case .pause:
                return "pause.fill"
            }
        }

        var buttonTitle: String {
            switch self {
            case .play:
                return L10n.play
            case .pause:
                return L10n.pause
            }
        }
    }

    var buttonState: ButtonState = .play {
        didSet {
            let config = UIImage.SymbolConfiguration(pointSize: 12, weight: .medium)
            let image = UIImage(systemName: buttonState.imageName, withConfiguration: config)?
                .withRenderingMode(.alwaysTemplate)
            let attributes: [NSAttributedString.Key: Any] = [
                        .font: UIFont.font(with: .callout, maxSizeCategory: .extraExtraExtraLarge)
            ]
            setAttributedTitle(NSAttributedString(string: buttonState.buttonTitle, attributes: attributes), for: .normal)
            setImage(image, for: .normal)
        }
    }

    func updateSize() {
        let attributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.font(with: .callout, maxSizeCategory: .extraExtraExtraLarge)
        ]
        setAttributedTitle(NSAttributedString(string: buttonState.buttonTitle, attributes: attributes), for: .normal)
    }

    static func makeButton(playbackManager: TranscriptPlaybackManaging) -> RoundPlayPauseButton {
        let titleColor = ThemeColor.primaryInteractive01()
        let tintColor = ThemeColor.primaryInteractive01().withAlphaComponent(0.1)

        var  bg = UIBackgroundConfiguration.clear()
        bg.backgroundColor = tintColor
        var configuration = UIButton.Configuration.filled()
        configuration.contentInsets = .init(top: 4, leading: 12, bottom: 4, trailing: 12)
        configuration.imagePadding = 8.0
        configuration.background = bg
        configuration.baseForegroundColor = ThemeColor.primaryInteractive01()

        let playButton = RoundPlayPauseButton(type: .system)
        playButton.playbackManager = playbackManager
        playButton.buttonState = playbackManager.isPlayingEpisode ? .pause : .play
        playButton.setupObservers()
        playButton.setTitleColor(titleColor, for: .normal)
        playButton.tintColor = tintColor
        playButton.layer.masksToBounds = true
        playButton.configuration = configuration
        return playButton
    }

    func setupObservers() {
        Publishers.Merge3(
            NotificationCenter.default.publisher(for: Constants.Notifications.playbackStarted),
            NotificationCenter.default.publisher(for: Constants.Notifications.playbackPaused),
            NotificationCenter.default.publisher(for: Constants.Notifications.playbackEnded)
        )
        .receive(on: RunLoop.main)
        .sink { [unowned self] _ in
            self.updatePlayingState()
        }
        .store(in: &cancellables)
    }

    private func updatePlayingState() {
        buttonState = playbackManager?.isPlayingEpisode == true ? .pause : .play
    }
}
