import SwiftUI
import PocketCastsDataModel
import Combine
import PocketCastsUtils
import EndOfYear
import CoreMedia
import UniformTypeIdentifiers

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
               style: ShareImageStyle,
               clipTime: ClipTime,
               clipUUID: String,
               progress: Binding<Float?>,
               presentFrom rect: CurrentValueSubject<CGRect, Never>) async throws {
        switch self {
        case .copyLink:
            UIPasteboard.general.string = option.shareURL
            Toast.show(L10n.shareCopiedToClipboard)
        case .systemSheet(let vc):
            let data = try await option.shareData(style: style, destination: self, clipUUID: clipUUID, progress: progress)
            let activityViewController = UIActivityViewController(activityItems: data, applicationActivities: nil)
            activityViewController.popoverPresentationController?.sourceView = vc.view
            activityViewController.popoverPresentationController?.sourceRect = rect.value
            let receiver = rect.sink { rect in
                activityViewController.popoverPresentationController?.sourceRect = rect
            }
            activityViewController.completionWithItemsHandler = { _, _, _, _ in
                receiver.cancel()
            }
            vc.presentedViewController?.present(activityViewController, animated: true)
        }
    }

    static func ==(lhs: ShareDestination, rhs: ShareDestination) -> Bool {
        lhs.name == rhs.name && lhs.icon == rhs.icon
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }
}

extension ShareDestination {
    enum VideoExportError: Error {
        case failedToDownload
    }

    func export(info: ShareImageInfo, style: ShareImageStyle, episode: some BaseEpisode, startTime: CMTime, duration: CMTime, scale: CGFloat, progress: Progress, to url: URL) async throws -> URL {
        guard let playerItem = DownloadManager.shared.downloadParallelToStream(of: episode) else {
            throw VideoExportError.failedToDownload
        }

        func exportVideo() async throws -> URL {
            let size = CGSize(width: style.previewSize.width, height: style.previewSize.height)

            let parameters = await VideoExporter.Parameters(duration: CMTimeGetSeconds(duration), size: size, scale: scale, episodeAsset: playerItem.asset, audioStartTime: startTime, audioDuration: duration, fileType: .mp4)
            try await VideoExporter.export(view: AnimatedShareImageView(info: info, style: style, size: size), with: parameters, to: url, progress: progress)

            return url
        }

        switch style {
        case .audio:
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("audio_export-\(UUID().uuidString)", conformingTo: .m4a)
            try await AudioClipExporter.exportAudioClip(from: playerItem.asset, startTime: startTime, duration: duration, to: url, progress: progress)
            return url
        default:
            return try await exportVideo()
        }
    }
}
