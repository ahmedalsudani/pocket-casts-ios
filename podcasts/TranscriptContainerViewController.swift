import UIKit

class TranscriptContainerViewController: UIViewController {
    private let playbackManager: TranscriptPlaybackManaging

    var playButtonTapped: ((Bool) -> Void)?

    private lazy var transcriptsItem: TranscriptViewController = {
        let item = TranscriptViewController(playbackManager: playbackManager, showFromEpisode: true)
        item.view.translatesAutoresizingMaskIntoConstraints = false
        item.containerDelegate = self
        item.playButtonTapped = playButtonTapped
        return item
    }()

    init(playbackManager: TranscriptPlaybackManaging) {
        self.playbackManager = playbackManager
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        showTranscript()
        presentationController?.delegate = self
    }

    func showTranscript() {
        addChild(transcriptsItem)
        view.addSubview(transcriptsItem.view)
        transcriptsItem.view.anchorToAllSidesOf(view: view)
        transcriptsItem.didMove(toParent: self)
        transcriptsItem.willBeAddedToPlayer()
        transcriptsItem.themeDidChange()
    }

    func hideTranscript() {
        transcriptsItem.willBeRemovedFromPlayer()
        transcriptsItem.willMove(toParent: nil)
        transcriptsItem.removeFromParent()
        transcriptsItem.view.removeFromSuperview()
    }
}

extension TranscriptContainerViewController: PlayerItemContainerDelegate {
    func dismissTranscript() {
        dismiss(animated: true) { [weak self] in
            self?.hideTranscript()
        }
    }

    func scrollToCurrentChapter() { }
    func scrollToNowPlaying() { }
    func scrollToBookmarks() { }
    func navigateToPodcast() { }
}

extension TranscriptContainerViewController: UIAdaptivePresentationControllerDelegate {
    func presentationControllerDidAttemptToDismiss(_ presentationController: UIPresentationController) { }

    func presentationControllerShouldDismiss(_ presentationController: UIPresentationController) -> Bool {
        return true
    }

    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        hideTranscript()
    }
}
