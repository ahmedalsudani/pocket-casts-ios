import Foundation
import PocketCastsDataModel
import PocketCastsUtils

public class UploadManager: NSObject {
    public static let shared = UploadManager()

    public var progressManager = UploadProgressManager()

    var uploadingEpisodesCache = [String: UserEpisode]()
    let imageTaskPrefix = "Image-"
    private lazy var wifiOnlyBackgroundSession: URLSession = {
        var config = URLSessionConfiguration.background(withIdentifier: "au.com.shiftyjelly.PCUploadBackgroundSession")
        config.allowsCellularAccess = false
        addStandardConfig(to: &config)

        let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        return session
    }()

    private lazy var cellularBackgroundSession: URLSession = {
        var config = URLSessionConfiguration.background(withIdentifier: "au.com.shiftyjelly.PCUploadManualSession")
        config.allowsCellularAccess = true
        addStandardConfig(to: &config)

        let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)

        return session
    }()

    private func addStandardConfig(to config: inout URLSessionConfiguration) {
        config.httpMaximumConnectionsPerHost = 1
        // disable cookies to prevent tracking, turns out people were actually using this the sneaky punks
        config.httpCookieStorage = nil
        config.httpShouldSetCookies = false
        config.httpCookieAcceptPolicy = .never
    }

    public lazy var customImageDirectory: String = {
        let directory = (NSHomeDirectory() as NSString).appendingPathComponent("Documents/custom_images")
        return directory
    }()

    override private init() {
        super.init()

        let fileManager = FileManager.default
        do {
            try fileManager.createDirectory(atPath: customImageDirectory, withIntermediateDirectories: true, attributes: nil)
        } catch {}
    }

    /// Local-only build: cloud upload is gone, nothing ever queues.
    public func queueForLaterUpload(episodeUuid: String, fireNotification: Bool) {
    }

    public func addToQueue(episodeUuid: String) {
        addToQueue(episodeUuid: episodeUuid, fireNotification: true)
    }

    /// Local-only build: cloud upload is gone, nothing ever queues.
    public func addToQueue(episodeUuid: String, fireNotification: Bool) {
    }

    private func performAddToQueue(episode: UserEpisode, previousUploadFailed: Bool, fireNotification: Bool) {
        let mobileDataAllowed = !ServerSettings.userEpisodeOnlyOnWifi()
        let useCellularSession = mobileDataAllowed && !NetworkUtils.shared.isConnectedToUnexpensiveConnection()
        let sessionToUse = useCellularSession ? cellularBackgroundSession : wifiOnlyBackgroundSession

        resumeUpload(episode: episode, session: sessionToUse, previousUploadFailed: previousUploadFailed, taskId: episode.uploadTaskId)
        if fireNotification { NotificationCenter.default.post(name: ServerNotifications.userEpisodeUploadStatusChanged, object: episode.uuid) }
    }

    public func removeFromQueue(episodeUuid: String, fireNotification: Bool) {
        guard let episode = DataManager.sharedManager.findUserEpisode(uuid: episodeUuid) else { return }

        removeFromQueue(episode: episode, fireNotification: fireNotification)
    }

    public func removeFromQueue(episode: UserEpisode, fireNotification: Bool) {
        guard let uploadId = episode.uploadTaskId else { return }

        cancelTaskId(uploadId, episode: episode, session: wifiOnlyBackgroundSession)
        cancelTaskId(uploadId, episode: episode, session: cellularBackgroundSession)

        let imageUploadId = imageTaskPrefix + uploadId
        cancelTaskId(imageUploadId, episode: episode, session: wifiOnlyBackgroundSession)
        cancelTaskId(imageUploadId, episode: episode, session: cellularBackgroundSession)

        removeTaskIdFromCache(taskId: imageUploadId)
        removeTaskIdFromCache(taskId: uploadId)

        episode.uploadTaskId = nil

        if episode.uploadQueued() || episode.uploading() || episode.uploadWaitingForWifi() {
            episode.uploadStatus = UploadStatus.notUploaded.rawValue
        }

        DataManager.sharedManager.save(episode: episode)

        if fireNotification { NotificationCenter.default.post(name: ServerNotifications.userEpisodeUploadStatusChanged, object: episode.uuid) }
    }

    private func shouldAddUpload(_ episodeUuid: String) -> Bool {
        guard let episode = DataManager.sharedManager.findUserEpisode(uuid: episodeUuid), let fileProtocol = ServerConfig.shared.syncDelegate?.userEpisodeFileProtocol, FileManager.default.fileExists(atPath: episode.pathToDownloadedFile(pathFinder: fileProtocol())) else { return false }

        if episode.uploadStatus == UploadStatus.notUploaded.rawValue || episode.uploadStatus == UploadStatus.uploadFailed.rawValue {
            DataManager.sharedManager.clearUploadTaskId(episode: episode)
        }

        return (episode.uploadTaskId == nil)
    }

    public func stopAllUploads() {
        for uploadTask in uploadingEpisodesCache {
            removeFromQueue(episodeUuid: uploadTask.value.uuid, fireNotification: false)
        }
    }

    private func cancelTaskId(_ taskId: String?, episode: UserEpisode, session: URLSession) {
        guard let taskId else { return }

        session.getTasksWithCompletionHandler { [weak self] _, uploadTasks, _ in
            if uploadTasks.isEmpty { return }

            for task in uploadTasks {
                if taskId == task.taskDescription {
                    self?.cancelTask(task, for: episode)

                    return
                }
            }
        }
    }

    private func cancelTask(_ task: URLSessionUploadTask, for episode: UserEpisode) {
        task.cancel()
    }

    public func removeTaskIdFromCache(taskId: String) {
        guard let episode = uploadingEpisodesCache[taskId] else { return }

        if !isImageUpload(taskId: taskId) {
            progressManager.removeProgressForEpisode(episode.uuid)
        }
        uploadingEpisodesCache.removeValue(forKey: taskId)
    }

    public func isImageUpload(taskId: String) -> Bool {
        taskId.contains(imageTaskPrefix)
    }

    private func resumeUpload(episode: UserEpisode, session: URLSession, previousUploadFailed: Bool, taskId: String?) {
        session.getTasksWithCompletionHandler { [weak self] _, uploadTasks, _ in
            if uploadTasks.isEmpty {
                self?.startUpload(episode: episode, session: session, previousUploadFailed: previousUploadFailed, taskId: taskId)
                return
            }

            let imageTaskId = UploadManager.shared.imageTaskPrefix + episode.uuid
            for task in uploadTasks {
                if taskId == task.taskDescription || imageTaskId == task.taskDescription {
                    task.resume()
                    return
                }
            }
            self?.startUpload(episode: episode, session: session, previousUploadFailed: previousUploadFailed, taskId: taskId)
        }
    }

    private func startUpload(episode: UserEpisode, session: URLSession, previousUploadFailed: Bool, taskId: String?) {
        ApiServerHandler.shared.uploadFileRequest(episode: episode, completion: { uploadURL in

            guard let url = uploadURL, let fileProtocol = ServerConfig.shared.syncDelegate?.userEpisodeFileProtocol else {
                DataManager.sharedManager.saveEpisode(uploadStatus: UploadStatus.uploadFailed, episode: episode)
                NotificationCenter.default.post(name: ServerNotifications.userEpisodeUploadStatusChanged, object: episode.uuid)
                return
            }

            var request = URLRequest(url: url)
            request.httpMethod = "PUT"

            request.addValue(episode.fileType ?? "audio/mp3", forHTTPHeaderField: ServerConstants.HttpHeaders.contentType)
            request.addValue("application/json", forHTTPHeaderField: ServerConstants.HttpHeaders.accept)
            request.addLocalizationHeaders()
            request.timeoutInterval = 30.seconds

            let uploadTask = session.uploadTask(with: request, fromFile: URL(fileURLWithPath: episode.pathToDownloadedFile(pathFinder: fileProtocol())))
            DataManager.sharedManager.saveEpisode(uploadStatus: UploadStatus.uploading, episode: episode)

            uploadTask.taskDescription = taskId
            if let taskId {
                self.uploadingEpisodesCache[taskId] = episode
            }
            uploadTask.resume()

            self.uploadImageFor(episode: episode, session: session)
        })
    }

    /// Local-only build: cloud upload is gone, custom artwork stays on device.
    public func uploadImageFor(episode: UserEpisode, session: URLSession?) {
    }
}
