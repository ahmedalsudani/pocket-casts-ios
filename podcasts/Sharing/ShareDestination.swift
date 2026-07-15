import SwiftUI
import PocketCastsDataModel
import Combine
import PocketCastsUtils

enum ShareDestination: Hashable {
    case copyLink
    case systemSheet(vc: UIViewController)

    var name: String {
        switch self {
        case .copyLink:
            L10n.shareCopyLink
        case .systemSheet:
            L10n.shareMoreActions
        }
    }

    var icon: Image {
        switch self {
        case .copyLink:
            Image("pocketcasts")
        case .systemSheet:
            Image(systemName: "ellipsis")
        }
    }

    @MainActor
    func share(_ option: SharingModal.Option,
               clipUUID: String,
               progress: Binding<Float?>,
               presentFrom rect: CurrentValueSubject<CGRect, Never>,
               source: AnalyticsSource) async throws {
        switch self {
        case .copyLink:
            UIPasteboard.general.string = option.shareURL
            Toast.show(L10n.shareCopiedToClipboard)
            ShareDestination.logClipShared(option: option, clipUUID: clipUUID, source: source)
            ShareDestination.logPodcastShared(option: option, destination: self, source: source)
        case .systemSheet(let vc):
            let data = try await option.shareData(clipUUID: clipUUID, progress: progress)
            let activityViewController = UIActivityViewController(activityItems: data, applicationActivities: nil)
            activityViewController.popoverPresentationController?.sourceView = vc.view
            activityViewController.popoverPresentationController?.sourceRect = rect.value
            let receiver = rect.sink { rect in
                activityViewController.popoverPresentationController?.sourceRect = rect
            }
            activityViewController.completionWithItemsHandler = { _, _, _, _ in
                receiver.cancel()
            }
            vc.presentedViewController?.present(activityViewController, animated: true, completion: {
                ShareDestination.logClipShared(option: option, clipUUID: clipUUID, source: source)
                ShareDestination.logPodcastShared(option: option, destination: self, source: source)
            })
        }
    }

    var analyticsDescription: String {
        switch self {
        case .copyLink:
            "url"
        case .systemSheet:
            "system_sheet"
        }
    }

    static func ==(lhs: ShareDestination, rhs: ShareDestination) -> Bool {
        lhs.name == rhs.name && lhs.icon == rhs.icon
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }
}

// MARK: Analytics

extension ShareDestination {
    private static func logClipShared(option: SharingModal.Option, clipUUID: String, source: AnalyticsSource) {
        // This event is specifically for clip shares and not other shares. These are handled by `podcastShared`
        guard case let .clipShare(episode, clipTime) = option else {
            return
        }

        var properties: Dictionary<String, Any> = [:]

        properties["episode_uuid"] = episode.uuid
        properties["podcast_uuid"] = episode.parentPodcast()?.uuid ?? "unknown"
        properties["start"] = Int(clipTime.start)
        properties["end"] = Int(clipTime.end)
        properties["start_modified"] = clipTime.startChanged
        properties["end_modified"] = clipTime.endChanged
        properties["clip_uuid"] = clipUUID
        properties["type"] = "audio"

        Analytics.track(.shareScreenClipShared, source: source, properties: properties)
    }

    private static func type(option: SharingModal.Option, destination: Self) -> String {
        switch option {
        case .podcast:
            return "podcast"
        case .episode:
            return "episode"
        case .currentPosition:
            return "current_time"
        case .bookmark:
            return "bookmark_time"
        case .clip, .clipShare:
            if case .copyLink = destination {
                return "clip_link"
            } else {
                return "clip_audio"
            }
        }
    }

    private static func logPodcastShared(option: SharingModal.Option, destination: Self, source: AnalyticsSource) {
        let properties: [String: Any] = [
            "type": type(option: option, destination: destination),
            "action": destination.analyticsDescription
        ]

        Analytics.track(.podcastShared, source: source, properties: properties)
    }
}
