import PocketCastsDataModel
import SwiftUI
import PocketCastsUtils
import EndOfYear

enum SharingModal {

    /// Share options including which type of content will be shared
    enum Option {
        case episode(Episode)
        case podcast(Podcast)
        case currentPosition(Episode, TimeInterval)
        case bookmark(Episode, TimeInterval)
        case clip(Episode, TimeInterval)
        case clipShare(Episode, ClipTime)

        var buttonTitle: String {
            switch self {
            case .episode:
                L10n.episode
            case .currentPosition, .bookmark:
                L10n.shareCurrentPosition
            case .podcast:
                L10n.podcastSingular
            case .clip, .clipShare:
                L10n.clip
            }
        }

        var shareTitle: String {
            switch self {
            case .episode:
                L10n.shareEpisode
            case .currentPosition(_, let time), .bookmark(_, let time):
                L10n.shareEpisodeAt(TimeFormatter.shared.playTimeFormat(time: time))
            case .podcast:
                L10n.sharePodcast
            case .clip:
                L10n.createClip
            case .clipShare:
                L10n.shareClip
            }
        }

        var shareDescription: String? {
            switch self {
            case .episode, .podcast:
                L10n.shareDescription
            case .clip, .clipShare:
                L10n.createAudioClipDescription
            default:
                nil
            }
        }

        static func allCases(episode: Episode?, podcast: Podcast, currentTime: TimeInterval) -> [Option] {
            if let episode {
                [
                    .episode(episode),
                    .podcast(podcast),
                    .currentPosition(episode, currentTime),
                    .clip(episode, currentTime)
                ]
            } else {
                [
                    .podcast(podcast)
                ]
            }
        }
    }

    static func showModal(episode: Episode, from source: AnalyticsSource, in viewController: UIViewController) {
        guard let podcast = episode.parentPodcast() else {
            assertionFailure("Podcast should exist for episode")
            return
        }
        showModal(podcast: podcast, episode: episode, from: source, in: viewController)
    }

    static func showModal(podcast: Podcast, episode: Episode?, from source: AnalyticsSource, in viewController: UIViewController) {

        if podcast.isPrivate {
            Toast.show(L10n.sharePodcastPrivateNotAvailable)
            return
        }

        let colors = OptionsPickerRootController.Colors(title: UIColor.white.withAlphaComponent(0.5), background: PlayerColorHelper.playerBackgroundColor01())

        let optionPicker = OptionsPicker(title: L10n.share.uppercased(), themeOverride: .dark, colors: colors)

        let timeInterval: Double
        if PlaybackManager.shared.currentEpisode()?.uuid == episode?.uuid {
            timeInterval = PlaybackManager.shared.currentTime()
        } else {
            timeInterval = episode?.playedUpTo ?? 0
        }

        let actions: [OptionAction] = Option.allCases(episode: episode, podcast: podcast, currentTime: timeInterval).map { option in
                .init(label: option.buttonTitle, action: {
                    show(option: option, from: source, in: viewController)
            })
        }
        optionPicker.addActions(actions)

        if let vc = (viewController as? EpisodeDetailViewController),
           let fileAction = vc.episodeFileAction(from: .zero) {
            optionPicker.addAction(action: fileAction)
        }

        optionPicker.show(statusBarStyle: AppTheme.defaultStatusBarStyle())
    }

    static func show(option: Option, from source: AnalyticsSource, in viewController: UIViewController) {

        if option.podcast.isPrivate {
            Toast.show(L10n.sharePodcastPrivateNotAvailable)
            return
        }

        let sharingDestinations: [ShareDestination] = [.copyLink, .systemSheet(vc: viewController)]
        let sharingView = SharingView(destinations: sharingDestinations, selectedOption: option, source: source)
        let modalView = ModalView {
            sharingView
        } dismissAction: {
            Analytics.track(.shareScreenCloseButtonTapped)
            viewController.dismiss(animated: true)
        }
        .background(Color(PlayerColorHelper.playerBackgroundColor01()))

        let hostingController = ThemedHostingController(rootView: modalView, theme: Theme(previewTheme: .contrastLight))
        viewController.present(hostingController, animated: true)
    }
}

extension SharingModal.Option {

    fileprivate var podcast: Podcast {
        switch self {
        case .episode(let episode), .currentPosition(let episode, _), .clip(let episode, _), .clipShare(let episode, _), .bookmark(let episode, _):
            return episode.parentPodcast()!
        case .podcast(let podcast):
            return podcast
        }
    }

    var artworkURL: URL {
        ImageManager.sharedManager.podcastUrl(imageSize: .page, uuid: podcast.uuid)
    }

    enum ExportError: Error {
        case failedToDownload
    }

    @MainActor
    func shareData(clipUUID: String, progress: Binding<Float?>) async throws -> [ActivityItemSourceItem] {
        let url = URL(string: shareURL) as NSURL?

        let media: Any?
        switch self {
        case .clipShare(let episode, let clipTime):
            media = try await mediaData(episode: episode, clipTime: clipTime, clipUUID: clipUUID, progress: progress)
        default:
            media = nil
        }

        return [url.map { ActivityItemSourceItem(item: $0, disallowedActivityTypes: [.airDrop]) },
                media.map { ActivityItemSourceItem(item: $0) }].compactMap({ $0 })
    }

    @MainActor
    func mediaData(episode: Episode, clipTime: ClipTime, clipUUID: String, progress: Binding<Float?>) async throws -> Any? {
        let nsProgress = Progress(totalUnitCount: 100)
        let observation = nsProgress.publisher(for: \.fractionCompleted).receive(on: DispatchQueue.main).sink(receiveValue: { fractionCompleted in
            guard Task.isCancelled == false && nsProgress.isCancelled == false else { return }
            progress.wrappedValue = Float(fractionCompleted)
        })

        defer {
            observation.cancel()
        }

        progress.wrappedValue = 0.01

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("audio_export-\(clipUUID)-\(clipTime.start)-\(clipTime.end)", conformingTo: .m4a)
        let fileURL: URL
        if FileManager.default.fileExistsAtURL(url) {
            fileURL = url
        } else {
            guard let playerItem = DownloadManager.shared.downloadParallelToStream(of: episode) else {
                throw ExportError.failedToDownload
            }
            try await AudioClipExporter.exportAudioClip(from: playerItem.asset,
                                                        startTime: CMTime(seconds: clipTime.start, preferredTimescale: 600),
                                                        duration: CMTime(seconds: clipTime.end - clipTime.start, preferredTimescale: 600),
                                                        to: url,
                                                        progress: nsProgress)
            fileURL = url
        }

        progress.wrappedValue = nil

        let components = [
            episode.parentPodcast()?.title,
            episode.title,
            "\(clipTime.start.secondsFormatted())-\(clipTime.end.secondsFormatted())"
        ].compactMap { $0 }

        let fileName = components.joined(separator: " - ").appending(".\(fileURL.pathExtension)").sanitizedFileName()
        var newURL = fileURL
        newURL.deleteLastPathComponent()
        newURL.appendPathComponent(fileName)

        if FileManager.default.fileExistsAtURL(newURL) {
            try FileManager.default.removeItem(at: newURL)
        }
        try FileManager.default.copyItem(at: fileURL, to: newURL)
        return newURL as NSURL // Third party apps need URLs and won't accept Data
    }

    // Timestamp query parameters only meant something to the Pocket Casts web
    // player; the feed/audio URLs shared now are used as-is.
    var shareURL: String {
        switch self {
        case .episode(let episode):
            return episode.shareURL
        case .podcast(let podcast):
            return podcast.shareURL
        case .currentPosition(let episode, _),
             .bookmark(let episode, _),
             .clip(let episode, _),
             .clipShare(let episode, _):
            return episode.shareURL
        }
    }
}

fileprivate extension TimeInterval {
    func secondsFormatted() -> String {
        String(format: "%.3f", self)
    }
}
