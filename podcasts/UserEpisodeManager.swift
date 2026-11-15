import Foundation
import PocketCastsDataModel
import PocketCastsServer
import PocketCastsUtils
import UIKit

struct UserEpisodeManager {
    #if !os(watchOS)
        static func addUserEpisode(uuid: String, title: String, localFileUrl: URL, artwork: UIImage?, color: Int, fileSize: Int, duration: TimeInterval) throws -> UserEpisode {
            let episode = UserEpisode()
            episode.title = title
            episode.addedDate = Date()
            episode.publishedDate = Date()
            episode.fileType = FileTypeUtil.typeForFileExtension(forExtension: localFileUrl.absoluteString)
            episode.duration = duration
            episode.uuid = uuid
            episode.sizeInBytes = Int64(fileSize)
            episode.episodeStatus = DownloadStatus.downloaded.rawValue
            if let artwork {
                episode.imageColor = 0
                do {
                    let filePath = episode.urlForImage()
                    try artwork.jpegData(compressionQuality: 1)?.write(to: filePath)
                    episode.hasCustomImage = true
                } catch {
                    throw error
                }
            } else {
                episode.imageColor = Int32(color)
                episode.hasCustomImage = false
            }

            DataManager.shared.save(episode: episode)

            if Settings.userEpisodeAutoAddToUpNext {
                PlaybackManager.shared.addToUpNext(episode: episode, userInitiated: false)
            }

            return episode
        }
    #endif

    static func renameUserEpisode(title: String, userEpisode: UserEpisode) {
        userEpisode.title = title
        DataManager.shared.save(episode: userEpisode)
    }

    // MARK: Delete

    static func deleteFromDevice(userEpisode: UserEpisode, removeFromPlaybackQueue: Bool = true) {
        DownloadManager.shared.removeFromQueue(episodeUuid: userEpisode.uuid, fireNotification: false, userInitiated: true)
        if removeFromPlaybackQueue {
            PlaybackManager.shared.removeIfPlayingOrQueued(episode: userEpisode, fireNotification: true)
        }
        EpisodeManager.deleteDownloadedFiles(episode: userEpisode)

        // a file only exists on this device, so once its audio is gone there's nothing left to keep
        DataManager.shared.delete(userEpisodeUuid: userEpisode.uuid)
        NotificationCenter.postOnMainThread(notification: Constants.Notifications.userEpisodeDeleted, object: userEpisode.uuid)
    }

    static func removeOrphanedUserEpisodes() {
        DataManager.shared.removeOrphanedUserEpisodes()
    }

    // MARK: - Update User Episode

    static func updateUserEpisode(uuid: String, title: String, color: Int) {
        guard let episode = DataManager.shared.findUserEpisode(uuid: uuid) else {
            return
        }
        if episode.title != title {
            episode.title = title
            episode.titleModified = TimeFormatter.currentUTCTimeInMillis()
        }
        if episode.imageColor != Int32(color) || episode.imageColorModified > 0 {
            episode.imageColor = Int32(color)
            episode.imageColorModified = TimeFormatter.currentUTCTimeInMillis()
        }

        DataManager.shared.save(episode: episode)
        NotificationCenter.postOnMainThread(notification: Constants.Notifications.userEpisodeUpdated, object: episode.uuid)
    }

    #if !os(watchOS)
        static func updateUserEpisodeImage(uuid: String, artwork: UIImage?, completion: @escaping () -> Void) throws {
            guard let episode = DataManager.shared.findUserEpisode(uuid: uuid) else {
                return
            }

            do {
                let imageUrl = episode.urlForImage()
                if imageUrl.isFileURL, FileManager.default.fileExists(atPath: imageUrl.absoluteString) { // remove Local artwork
                    try FileManager.default.removeItem(at: imageUrl)
                }

                ImageManager.shared.removeUserEpisodeImage(episode: episode, completionHandler: {
                    episode.imageUrl = nil
                    if episode.imageColor != 0 {
                        episode.imageColor = 0
                        episode.imageColorModified = TimeFormatter.currentUTCTimeInMillis()
                    }

                    let filePath = episode.urlForImage()
                    if let artwork {
                        do {
                            try artwork.jpegData(compressionQuality: 1)?.write(to: filePath)
                            episode.imageModified = TimeFormatter.currentUTCTimeInMillis()
                        } catch {
                            //   throw error
                            print("failed to save artowrk")
                        }
                        episode.hasCustomImage = true
                    }
                    DataManager.shared.save(episode: episode)
                    NotificationCenter.postOnMainThread(notification: Constants.Notifications.userEpisodeUpdated, object: episode.uuid)
                    completion()
                })
            } catch {
                throw error
            }
        }
    #endif

    #if !os(watchOS)
    static func presentDeleteOptions(episode: UserEpisode, from presenter: UIViewController, deleteCallback: (() -> Void)? = nil) {
        let cancelAction = UIAlertAction(title: L10n.cancel, style: .cancel)

        let deleteAction = UIAlertAction(title: L10n.deleteFromDevice, style: .destructive) { _ in
            UserEpisodeManager.deleteFromDevice(userEpisode: episode)
            deleteCallback?()
        }

        let alert = UIAlertController(title: L10n.deleteFromDevice, message: L10n.deleteFileMessage, preferredStyle: .alert)
        alert.addAction(cancelAction)
        alert.addAction(deleteAction)
        presenter.present(alert, animated: true)
    }
    #endif
}
