import PocketCastsDataModel
import UIKit

@MainActor
class SharingHelper: NSObject {
    static let shared = SharingHelper()
    func shareLinkTo(podcast: Podcast, fromController: UIViewController, sourceRect: CGRect, sourceView: UIView) {

        guard !podcast.isPrivate else {
            Toast.show(L10n.sharePodcastPrivateNotAvailable)
            return
        }

        SharingModal.show(option: .podcast(podcast), in: fromController)
    }

    func shareLinkTo(podcast: Podcast, fromController: UIViewController, barButtonItem: UIBarButtonItem?) {
        guard !podcast.isPrivate else {
            Toast.show(L10n.sharePodcastPrivateNotAvailable)
            return
        }

        SharingModal.show(option: .podcast(podcast), in: fromController)
    }

    func shareLinkTo(episode: Episode, shareTime: TimeInterval, fromController: UIViewController, barButtonItem: UIBarButtonItem?) {
        let option: SharingModal.Option = shareTime == 0 ? .episode(episode) : .currentPosition(episode, shareTime)
        SharingModal.show(option: option, in: fromController)
    }

    func shareLinkTo(episode: Episode, shareTime: TimeInterval, fromController: UIViewController, sourceRect: CGRect, sourceView: UIView?, showArrow: Bool = true) {
        let option: SharingModal.Option = shareTime == 0 ? .episode(episode) : .currentPosition(episode, shareTime)
        SharingModal.show(option: option, in: fromController)
    }
}

// Share things any podcast app can open: the feed for a podcast, the audio file for an episode.
extension Podcast {
    var shareURL: String {
        feedUrl ?? podcastUrl ?? ""
    }
}

extension Episode {
    var shareURL: String {
        downloadUrl ?? parentPodcast()?.shareURL ?? ""
    }
}
