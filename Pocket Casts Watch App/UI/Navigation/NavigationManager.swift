import Foundation
import PocketCastsDataModel
import PocketCastsUtils
import WatchKit

class NavigationManager: ObservableObject {
    static let shared = NavigationManager()

    @Published var currentInterface: WatchInterfaceType?

    func navigateToRestorable(name: String, context: Any?) {
        let interfaceType = WatchInterfaceType(rawValue: name)

        if interfaceType == .nowPlaying {
            navigateToNowPlaying()
        } else if let interfaceType {
            navigateTo(interfaceType, context: context)
        }
    }

    func navigateTo(_ type: WatchInterfaceType, context: Any?) {
        switch type {
        case .downloads, .files, .upnext, .nowPlaying, .filterList:
            currentInterface = type
        case .unknown, .effects, .episodeDetails, .filter, .interface:
            currentInterface = nil
        }
    }

    func navigateToNowPlaying() {
        navigateTo(.nowPlaying, context: nil)
    }
}
