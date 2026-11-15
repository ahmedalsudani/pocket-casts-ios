import CoreServices
import Foundation
import JLRoutes
import PocketCastsDataModel
import PocketCastsServer
import PocketCastsUtils
import UIKit
import UniformTypeIdentifiers

extension AppDelegate {
    func application(_ application: UIApplication, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        appDelegate()?.handleShortcutItem(shortcutItem)
    }

    func handleShortcutItem(_ shortcutItem: UIApplicationShortcutItem) {
        if let urlString = shortcutItem.userInfo?["url"] as? String, let url = URL(string: urlString) {
            JLRoutes.routeURL(url)
        }
    }

    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        guard let progressViewController = SceneHelper.rootViewController() else { return false }
        return handleOpenUrl(url: url, rootViewController: progressViewController)
    }

    func handleOpenUrl(url: URL, rootViewController: UIViewController) -> Bool {
        if url.isFileURL {
            guard let type = UTType(filenameExtension: url.pathExtension) else { return false }

            let supportedTypes: [UTType] = [.xml, UTType("public.opml"), UTType("unofficial.opml")].compactMap { $0 }

            let isSupported = supportedTypes.contains { supportedType in
                type.conforms(to: supportedType)
            }

            if let fileExtension = UTType.pcasts.preferredFilenameExtension, type.conforms(to: UTType(filenameExtension: fileExtension)!) {
                let alert = UIAlertController(title: L10n.pcastsImportTitle, message: L10n.pcastsImportMessage, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: L10n.import, style: .destructive) { _ in
                    Task {
                        do {
                            let fileWrapper = try FileWrapper(url: url)
                            try PCBundleDoc.performImport(from: fileWrapper)
                        } catch {
                            FileLog.shared.addMessage("File Import failed with error \(error)")
                        }
                    }
                })
                alert.addAction(UIAlertAction(title: L10n.cancel, style: .cancel))
                rootViewController.present(alert, animated: true)
            }

            if isSupported {
                progressDialog = ShiftyLoadingAlert(title: L10n.opmlImporting)
                rootViewController.dismiss(animated: false, completion: nil)
                progressDialog?.showAlert(rootViewController, hasProgress: false, completion: { [weak self] in
                    if let progressDialog = self?.progressDialog {
                        PodcastManager.shared.importPodcastsFromOpml(url, progressWindow: progressDialog)
                    }
                })
            } else if type.conforms(to: .audio) || type.conforms(to: .movie) {
                NavigationManager.shared.navigateTo(NavigationManager.uploadedPageKey, data: [NavigationManager.uploadFileKey: url])
            }
        } else {
            // check to see what the scheme is we support itpc, http, feed & our own pktc
            if let scheme = url.scheme, scheme == "pktc" {
                JLRoutes.routeURL(url)
            }
        }
        return true
    }

    func setupRoutes() {
        // 3D touch shortcuts
        JLRoutes.global().addRoute("/shortcuts/:shortcut") { [weak self] parameters -> Bool in
            guard let strongSelf = self, let shortcut = parameters["shortcut"] as? String else { return false }

            if shortcut == "pause" {
                PlaybackManager.shared.pause()
                strongSelf.openPlayerWhenReadyFromExternalEvent()
            } else if shortcut == "play" {
                PlaybackManager.shared.play()
                strongSelf.openPlayerWhenReadyFromExternalEvent()
            } else if shortcut == "markAsPlayed" {
                if let episode = PlaybackManager.shared.currentEpisode {
                    EpisodeManager.markAsPlayed(episode: episode, fireNotification: true)
                }
            } else if shortcut == "discover" {
                NavigationManager.shared.navigateTo(NavigationManager.discoverPageKey, data: nil)
            }

            return true
        }

        // open a playlist from a shortcut
        JLRoutes.global().addRoute("/shortcuts/filter/:filterId") { parameters -> Bool in
            guard let playlistId = parameters["filterId"] as? String, let playlist = DataManager.shared.findPlaylist(uuid: playlistId) else { return false }

            NavigationManager.shared.navigateTo(NavigationManager.filterPageKey, data: [NavigationManager.filterUuidKey: playlist.uuid])

            return true
        }

        // open a podcast from a shortcut
        JLRoutes.global().addRoute("/shortcuts/podcast/:podcastUuid") { parameters -> Bool in
            guard let podcastUuid = parameters["podcastUuid"] as? String, let podcast = DataManager.shared.findPodcast(uuid: podcastUuid) else { return false }

            NavigationManager.shared.navigateTo(NavigationManager.podcastPageKey, data: [NavigationManager.podcastKey: podcast])

            return true
        }

        // URL schemes for open, play, pause
        JLRoutes.global().addRoute("/open") { _ -> Bool in
            true
        }
        JLRoutes.global().addRoute("/play") { _ -> Bool in
            PlaybackManager.shared.play()

            return true
        }
        JLRoutes.global().addRoute("/pause") { _ -> Bool in
            PlaybackManager.shared.pause()

            return true
        }

        // Open to discover
        JLRoutes.global().addRoute("/discover/*") { paramDict -> Bool in

            NavigationManager.shared.navigateTo(NavigationManager.discoverPageKey, data: nil)

            return true
        }
        // Support for subscribing to a feed URL
        JLRoutes.global().addRoute("/subscribe/*") { [weak self] parameters -> Bool in
            guard
                let strongSelf = self,
                let rootController = SceneHelper.rootViewController(includeTopMost: false), //I don't want to consider the top most presented but the main root instead
                let subscribeUrl = (parameters[JLRouteURLKey] as? URL)?.absoluteString
            else {
                return false
            }

            let prefix = "pktc://subscribe/"
            if prefix.count >= subscribeUrl.count { return true } // this request is missing a URL

            let feedUrl = subscribeUrl.replacingOccurrences(of: prefix, with: "")

            let searchTerm = !feedUrl.hasPrefix("http://") && !feedUrl.hasPrefix("https://") ? "http://\(feedUrl)" : feedUrl

            strongSelf.progressDialog = ShiftyLoadingAlert(title: L10n.podcastLoading)
            rootController.dismiss(animated: false, completion: nil)
            strongSelf.progressDialog?.showAlert(rootController, hasProgress: false, completion: {
                guard let url = URL(string: searchTerm) else {
                    DispatchQueue.main.async {
                        self?.hideProgressDialog()
                        SJUIUtils.showAlert(title: L10n.error, message: L10n.errorGeneralPodcastNotFound, from: SceneHelper.rootViewController())
                    }
                    return
                }
                ServerPodcastManager.shared.addFromFeedURL(url, subscribe: false) { success, uuid in
                    DispatchQueue.main.async {
                        self?.hideProgressDialog()
                        if success, let uuid {
                            NavigationManager.shared.navigateTo(NavigationManager.podcastPageKey, data: [NavigationManager.podcastKey: uuid])
                        } else {
                            SJUIUtils.showAlert(title: L10n.error, message: L10n.errorGeneralPodcastNotFound, from: SceneHelper.rootViewController())
                        }
                    }
                }
            })

            return true
        }

        // Today Centre Widget thingy
        JLRoutes.global().addRoute("/widget/*") { [weak self] parameters -> Bool in
            guard let strongSelf = self, let pathComponents = parameters[JLRouteWildcardComponentsKey] as? [String], let episodeUuid = pathComponents[safe: 0] else { return false }

            guard let episode = DataManager.shared.findEpisode(uuid: episodeUuid) else { return true }

            strongSelf.openPlayerWhenReadyFromExternalEvent()

            if PlaybackManager.shared.isCurrentEpisode(uuid: episode.uuid) {
                if !PlaybackManager.shared.isPlaying {
                    PlaybackManager.shared.play()
                }
            } else {
                PlaybackManager.shared.load(episode: episode, autoPlay: true, overrideUpNext: false)
            }

            return true
        }

        // Home screen Widget
        JLRoutes.global().addRoute("/widget-episode/*") { [weak self] parameters -> Bool in
            guard let strongSelf = self, let pathComponents = parameters[JLRouteWildcardComponentsKey] as? [String], let episodeUuid = pathComponents[safe: 0] else { return false }

            guard let baseEpisode = DataManager.shared.findBaseEpisode(uuid: episodeUuid) else { return true }

            if PlaybackManager.shared.isCurrentEpisode(uuid: baseEpisode.uuid) {
                strongSelf.openPlayerWhenReadyFromExternalEvent()
            } else {
                if let episode = baseEpisode as? Episode {
                    NavigationManager.shared.navigateTo(NavigationManager.episodePageKey, data: [NavigationManager.episodeUuidKey: episode.uuid])
                } else if baseEpisode is UserEpisode {
                    NavigationManager.shared.navigateTo(NavigationManager.filesPageKey, data: nil)
                }
            }
            return true
        }

        JLRoutes.global().addRoute("/last_opened/*") { _ in
            return true
        }

        JLRoutes.global().addRoute("/show_player") { [weak self] _ -> Bool in
            self?.openPlayerWhenReadyFromExternalEvent()
            return true
        }

        JLRoutes.global().addRoute("/upnext/*") { [weak self] paramDict -> Bool in
            var showFromMiniPlayer: Bool = true
            if let location = paramDict["location"] as? String, location == "tab" {
                showFromMiniPlayer = false
            }
            if showFromMiniPlayer {
                self?.miniPlayer()?.showUpNext()
            } else {
                NavigationManager.shared.navigateTo(NavigationManager.upNextPageKey)
            }

            return true
        }

        // Import OMPL extension
        JLRoutes.global().addRoute("/import-file/*") { [weak self] parameters -> Bool in
            guard let self,
                  let rootViewController = SceneHelper.rootViewController(),
                  let originalUrl = parameters[JLRouteURLKey] as? URL else { return false }

            let fileURLString = originalUrl.absoluteString.replacingOccurrences(of: "pktc://import-file/", with: "")

            guard let fileURL = URL(string: fileURLString) else {
                return true
            }

            return self.handleOpenUrl(url: fileURL, rootViewController: rootViewController)
        }

        setupOnboardingRoutes()
        setupProfileRoutes()
    }

    func setupOnboardingRoutes() {
        JLRoutes.global().addRoute("/settings/themes") {[weak self] _ -> Bool in
            guard self != nil else { return false }
            NavigationManager.shared.navigateTo(NavigationManager.settingsAppearanceKey, data: [NavigationManager.settingsAppearanceShowThemeKey: true])
            return true
        }

        JLRoutes.global().addRoute("/settings/import") {[weak self] _ -> Bool in
            guard self != nil else { return false }
            NavigationManager.shared.navigateTo(NavigationManager.settingsPageKey, data: [NavigationManager.settingsRowKey: SettingsViewController.TableRow.importSteps])
            return true
        }

        JLRoutes.global().addRoute("/settings/storage-and-data") {[weak self] _ -> Bool in
            guard self != nil else { return false }
            NavigationManager.shared.navigateTo(NavigationManager.settingsPageKey, data: [NavigationManager.settingsRowKey: SettingsViewController.TableRow.storageAndDataUse])
            return true
        }

        JLRoutes.global().addRoute("/filters") {[weak self] _ -> Bool in
            guard self != nil else { return false }
            NavigationManager.shared.navigateTo(NavigationManager.filterPageKey)
            return true
        }

    }

    func setupProfileRoutes() {
        JLRoutes.global().addRoute("/profile/*") { [weak self] parameters -> Bool in
            guard self != nil,
                  let pathComponents = parameters[JLRouteWildcardComponentsKey] as? [String],
                  let row = pathComponents.first
            else {
                NavigationManager.shared.navigateTo(NavigationManager.settingsProfileKey, data: [:])
                return true
            }
            NavigationManager.shared.navigateTo(NavigationManager.settingsProfileKey, data: [NavigationManager.profileRowKey: row])
            return true
        }
    }

}
