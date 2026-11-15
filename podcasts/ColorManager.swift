import PocketCastsUtils
import PocketCastsDataModel
import UIKit

class ColorManager {
    private let defaultBackgroundColor = UIColor(hex: "#3D3D3D")
    private let defaultLightTintColor = UIColor(hex: "#1E1F1E")
    private let defaultDarkTintColor = UIColor(hex: "#FFFFFF")

    private let defaultServerLightTint = "#F44336"
    private let defaultServerDarkTint = "#C62828"

    private let currentColorVersion = 4 as Int32

    static let shared = ColorManager()

    private init() {}

    class func backgroundColor(for podcast: Podcast) -> UIColor {
        ColorManager.shared.backgroundColor(for: podcast)
    }

    class func backgroundColor(forPodcastUuid uuid: String) -> UIColor {
        guard let podcast = DataManager.shared.findPodcast(uuid: uuid, includeUnsubscribed: true) else {
            return ColorManager.shared.defaultBackgroundColor
        }
        return ColorManager.shared.backgroundColor(for: podcast)
    }

    class func lightThemeTint(for podcast: Podcast, defaultColor: UIColor? = nil) -> UIColor {
        ColorManager.shared.lightThemeTint(for: podcast, defaultColor: defaultColor)
    }

    class func darkThemeTint(for podcast: Podcast, defaultColor: UIColor? = nil) -> UIColor {
        ColorManager.shared.darkThemeTint(for: podcast, defaultColor: defaultColor)
    }

    private func backgroundColor(for podcast: Podcast) -> UIColor {
        if let colorStr = podcast.backgroundColor, podcast.colorVersion == currentColorVersion {
            return UIColor(hex: colorStr)
        }

        return defaultBackgroundColor
    }

    private func lightThemeTint(for podcast: Podcast, defaultColor: UIColor? = nil) -> UIColor {
        if let colorStr = podcast.primaryColor, podcast.colorVersion == currentColorVersion {
            if colorStr == defaultServerLightTint {
                return defaultColor ?? defaultLightTintColor
            }

            return UIColor(hex: colorStr)
        }

        return defaultColor ?? defaultLightTintColor
    }

    private func darkThemeTint(for podcast: Podcast, defaultColor: UIColor? = nil) -> UIColor {
        if let colorStr = podcast.secondaryColor, podcast.colorVersion == currentColorVersion {
            if colorStr == defaultServerDarkTint {
                return defaultColor ?? defaultDarkTintColor
            }

            return UIColor(hex: colorStr)
        }

        return defaultColor ?? defaultDarkTintColor
    }
}
