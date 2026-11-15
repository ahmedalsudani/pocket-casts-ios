import Foundation
import PocketCastsDataModel
import PocketCastsUtils

extension DownloadManager {
    func clearStuckDownloads() async {
        let episodesWithDownloadIds = dataManager.findEpisodesWhereNotNull(propertyName: "downloadTaskId")

        var episodeUuids = episodesWithDownloadIds.map { $0.uuid }

        let tasks = await allTasks()

        tasks.forEach { task in
            if let taskDescription = task.taskDescription {
                if let episode = dataManager.findBaseEpisode(downloadTaskId: taskDescription), let index = episodeUuids.firstIndex(of: episode.uuid) {
                    episodeUuids.remove(at: index)
                } else {
                    task.cancel()
                }
            } else {
                task.cancel()
            }
        }

        if episodeUuids.isEmpty { return }

        for episodeUuid in episodeUuids {
            guard let episode = DataManager.shared.findBaseEpisode(uuid: episodeUuid) else { continue }

            let downloadStatus: DownloadStatus = episode.downloaded(pathFinder: self) ? .downloaded : .notDownloaded
            dataManager.saveEpisode(downloadStatus: downloadStatus, downloadTaskId: nil, episode: episode)
            FileLog.shared.addMessage("Clearing download status on an episode that isn't downloading anymore: \(episode.displayableTitle())")
        }
    }
}
