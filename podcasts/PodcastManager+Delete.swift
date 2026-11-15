import Foundation
import PocketCastsDataModel
import PocketCastsServer
import PocketCastsUtils

extension PodcastManager {
    func unsubscribe(podcast: Podcast) {
        let savedFolderUuid = podcast.folderUuid

        EpisodeManager.deleteAllEpisodesInPodcast(id: podcast.id)
        dataManager.delete(podcast: podcast)

        PlaylistManager.handlePodcastUnsubscribed(podcastUuid: podcast.uuid)

        // additionally if this podcast was in a folder, update the folder
        if let folderUuid = savedFolderUuid {
            dataManager.updateFolderSyncModified(folderUuid: folderUuid, syncModified: TimeFormatter.currentUTCTimeInMillis())
            NotificationCenter.postOnMainThread(notification: Constants.Notifications.folderChanged, object: folderUuid)
        }

        NotificationCenter.postOnMainThread(notification: Constants.Notifications.podcastDeleted, object: podcast.uuid)
    }
}
