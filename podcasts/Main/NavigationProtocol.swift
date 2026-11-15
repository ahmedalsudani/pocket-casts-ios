import Foundation
import PocketCastsDataModel
import PocketCastsServer
import UIKit

protocol NavigationProtocol: AnyObject {
    func navigateToPodcastList(_ animated: Bool)
    func navigateToPodcast(_ podcast: Podcast)
    func navigateToPodcastInfo(_ podcastInfo: PodcastInfo)
    func navigateTo(podcast searchResult: PodcastFolderSearchResult)

    func navigateToFolder(_ folder: Folder, popToRootViewController: Bool)

    func navigateToEpisode(_ episodeUuid: String, podcastUuid: String?, timestamp: TimeInterval?)

    func navigateToDiscover(_ animated: Bool)

    func navigateToProfile(row: ProfileViewController.TableRow?, animated: Bool)

    func navigateToFilter(_ filter: EpisodeFilter?, animated: Bool)
    func navigateToAddFilter()
    func presentManualPlaylistsChooser(for episode: Episode, rootViewController: UIViewController?)

    func navigateToUpNext(_ animated: Bool)

    func navigateToFiles()
    func navigateToAddCustom(_ fileURL: URL)

    func showSettings(row: SettingsViewController.TableRow?)
    func showSettingsAppearance(showThemeSelection: Bool)
    func showHeadphoneSettings()
    func showGeneralSettings(row: GeneralSettingsViewController.TableRow?)

    func showInSafariViewController(urlString: String)

    func showEndOfYearStories()
    func dismissPresentedViewController(completion: (() -> Void)?)
    func showNotificationsPermissions()
}
