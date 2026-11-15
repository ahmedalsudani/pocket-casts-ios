import Foundation
import PocketCastsDataModel
import PocketCastsServer
import PocketCastsUtils

extension UserEpisode {
    // MARK: - Helpers

    func displayableInfo(includeSize: Bool = true) -> String {
        commonDisplayableInfo(includeSize: includeSize)
    }

    func displayableDuration(includeSize: Bool = true) -> String {
        var informationLabelStr = duration > 0 ? displayableTimeLeft() : L10n.unknownDuration

        if includeSize, sizeInBytes > 0 {
            if informationLabelStr.isEmpty {
                informationLabelStr = SizeFormatter.shared.noDecimalFormat(bytes: sizeInBytes)
            } else {
                informationLabelStr += " • \(SizeFormatter.shared.noDecimalFormat(bytes: sizeInBytes))"
            }
        }

        return informationLabelStr
    }

    public func shouldArchiveOnCompletion() -> Bool {
        Settings.userEpisodeRemoveFileAfterPlaying
    }

    func urlForImage(size: Int = 280) -> URL {
        if imageColor > 0 {
            #if !os(watchOS)
                return ServerHelper.userEpisodeDefaultImageUrl(isDark: Theme.isDarkTheme, color: Int(imageColor), size: size)
            #else
                return ServerHelper.userEpisodeDefaultImageUrl(isDark: true, color: Int(imageColor), size: size)
            #endif
        }

        if let serverImageLocation = imageUrl, let serverURL = URL(string: serverImageLocation) {
            return serverURL
        }
        #if !os(watchOS)
            let path = pathToLocalImage()
            return URL(fileURLWithPath: path)
        #else
            return ServerHelper.userEpisodeDefaultImageUrl(isDark: true, color: 1, size: size)
        #endif
    }

    /// Where the images picked for files are kept
    private static let customImageDirectory: String = {
        let directory = (NSHomeDirectory() as NSString).appendingPathComponent("Documents/custom_images")
        try? FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true, attributes: nil)
        return directory
    }()

    func pathToLocalImage() -> String {
        Self.customImageDirectory + "/" + uuid + ".jpg"
    }

    public func subTitle() -> String {
        uploadStatus == UploadStatus.missing.rawValue ? L10n.downloadErrorNotUploaded : L10n.customEpisode
    }
}
