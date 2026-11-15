import PocketCastsUtils
import Foundation
import GRDB

class EpisodeDataManager {
    enum Constants {
        enum Limits {
            static let maxPlaylistItems = 1000
            /// How many episodes `insertMissing` saves in one write
            static let insertMissingChunkSize = 100
        }
    }

    private static let sequentialEpisodeIdsKey = "SequentialEpisodeIds"

    /// `true` if the database was created by a version that gives new episodes sequential IDs and the flag is on
    private let givesSequentialIds: Bool
    private var largestEpisodeId: Int64 = 0

    init(databaseWasCreated: Bool, userDefaults: UserDefaults) {
        if databaseWasCreated {
            userDefaults.set(true, forKey: Self.sequentialEpisodeIdsKey)
        }
        givesSequentialIds = userDefaults.bool(forKey: Self.sequentialEpisodeIdsKey) && FeatureFlag.sequentialEpisodeIds.enabled
    }

    func setup(dbQueue: GRDBQueue) {
        guard givesSequentialIds else { return }

        do {
            try dbQueue.dbPool.writeWithoutTransaction { db in
                try rememberLargestEpisodeId(in: db)
            }
        } catch {
            FileLog.shared.addMessage("EpisodeDataManager.setup error: \(error)")
        }
    }

    // MARK: - Query

    func findBy(uuid: String, dbQueue: GRDBQueue) -> Episode? {
        loadSingle(query: "SELECT * from \(DataManager.episodeTableName) WHERE uuid = ?", values: [uuid], dbQueue: dbQueue)
    }

    func findWhere(customWhere: String, arguments: [Any]?, dbQueue: GRDBQueue) -> Episode? {
        loadSingle(query: "SELECT * from \(DataManager.episodeTableName) WHERE \(customWhere)", values: arguments, dbQueue: dbQueue)
    }

    func findPlayedEpisodes(uuids: [String], dbQueue: GRDBQueue) -> [String] {
        let list = uuids.map { "'\($0)'" }.joined(separator: ",")

        let query = """
        SELECT * from \(DataManager.episodeTableName)
        WHERE uuid IN (\(list))
        AND playingStatus = ?
        LIMIT \(uuids.count)
        """

        var episodes = [String]()
        dbQueue.read { db in
            do {
                let resultSet = try db.executeQuery(query, values: [PlayingStatus.completed.rawValue])

                while resultSet.next() {
                    let uuid = DBUtils.nonNilStringFromColumn(resultSet: resultSet, columnName: "uuid")
                    episodes.append(uuid)
                }
            } catch {
                FileLog.shared.addMessage("EpisodeDataManager.loadMultiple Episode error: \(error)")
            }
        }
        return episodes
    }

    func findMatchingEpisodes(uuids: [String], dbQueue: GRDBQueue) -> [String] {
        let list = uuids.map { "'\($0)'" }.joined(separator: ",")

        let query = """
        SELECT uuid from \(DataManager.episodeTableName)
        WHERE uuid IN (\(list))
        LIMIT \(uuids.count)
        """

        var episodes = [String]()
        dbQueue.read { db in
            do {
                let resultSet = try db.executeQuery(query, values: nil)

                while resultSet.next() {
                    let uuid = DBUtils.nonNilStringFromColumn(resultSet: resultSet, columnName: "uuid")
                    episodes.append(uuid)
                }
            } catch {
                FileLog.shared.addMessage("EpisodeDataManager.findMissingEpisodes error: \(error)")
            }
        }

        return episodes
    }

    func downloadedEpisodeExists(uuid: String, dbQueue: GRDBQueue) -> Bool {
        var found = false
        dbQueue.read { db in
            do {
                let resultSet = try db.executeQuery("SELECT id from \(DataManager.episodeTableName) WHERE episodeStatus = ? AND uuid = ?", values: [DownloadStatus.downloaded.rawValue, uuid])

                if resultSet.next() {
                    found = true
                }
            } catch {
                FileLog.shared.addMessage("EpisodeDataManager.downloadedEpisodeExists error: \(error)")
            }
        }

        return found
    }

    func findBy(downloadTaskId: String, dbQueue: GRDBQueue) -> Episode? {
        loadSingle(query: "SELECT * from \(DataManager.episodeTableName) WHERE downloadTaskId = ?", values: [downloadTaskId], dbQueue: dbQueue)
    }

    func findWhereNotNull(columnName: String, dbQueue: GRDBQueue) -> [Episode] {
        loadMultiple(query: "SELECT * from \(DataManager.episodeTableName) WHERE \(columnName) IS NOT NULL", values: nil, dbQueue: dbQueue)
    }

    func findEpisodesAndPodcastsWhere(customWhere: String, listenedTo: Bool, dbQueue: GRDBQueue) -> [Episode] {
        let listenedToQuery: String = """
        lastPlaybackInteractionDate IS NOT NULL
        AND lastPlaybackInteractionDate > 0
        AND
        """
        let query = """
        SELECT episode.* FROM \(DataManager.episodeTableName) episode
        LEFT JOIN \(DataManager.podcastTableName) podcast ON episode.podcast_id = podcast.id
        WHERE
        \(listenedTo ? listenedToQuery : "")
        (UPPER(episode.title) LIKE '%' || UPPER(?) || '%'  ESCAPE '\\'
         OR UPPER(podcast.title) LIKE '%' || UPPER(?) || '%'  ESCAPE '\\')
        ORDER BY lastPlaybackInteractionDate DESC LIMIT 1000
        """
        return loadMultiple(query: query, values: [customWhere, customWhere], dbQueue: dbQueue)
    }

    func findEpisodesWhere(customWhere: String, arguments: [Any]?, dbQueue: GRDBQueue) -> [Episode] {
        loadMultiple(query: "SELECT * from \(DataManager.episodeTableName) WHERE \(customWhere)", values: arguments, dbQueue: dbQueue)
    }

    func findEpisodes(with term: String, podcastUUID: String, dbQueue: GRDBQueue) -> [Episode] {
        let escapedSearch = term.escapeLike(escapeChar: "\\")
        let query = """
        (UPPER(title) LIKE '%' || UPPER(?) || '%'  ESCAPE '\\' AND
        podcastUuid = ? AND wasDeleted = 0)
        ORDER BY publishedDate DESC, addedDate DESC
        """

        return findEpisodesWhere(customWhere: query, arguments: [escapedSearch, podcastUUID], dbQueue: dbQueue)
    }

    func findEpisodes(matching term: String, limit: Int, dbQueue: GRDBQueue) -> [Episode] {
        let escapedSearch = term.escapeLike(escapeChar: "\\")
        let query = """
        (UPPER(title) LIKE '%' || UPPER(?) || '%'  ESCAPE '\\' AND
        podcastUuid IN (SELECT uuid FROM \(DataManager.podcastTableName) WHERE subscribed = 1) AND wasDeleted = 0)
        ORDER BY publishedDate DESC, addedDate DESC LIMIT \(limit)
        """

        return findEpisodesWhere(customWhere: query, arguments: [escapedSearch], dbQueue: dbQueue)
    }

    func findPlaylistEpisodesWhere(query: String, arguments: [Any]?, dbQueue: GRDBQueue) -> [Episode] {
        loadMultiple(query: query, values: arguments, dbQueue: dbQueue)
    }

    func allEpisodes(forPodcastId id: Int64, dbQueue: GRDBQueue) -> [Episode] {
        loadMultiple(query: "SELECT * from \(DataManager.episodeTableName) WHERE podcast_id = ? AND wasDeleted = 0", values: [id], dbQueue: dbQueue)
    }

    /// Returns daily listening totals as `[dateString: totalSeconds]` for the past N days.
    /// Date strings are formatted as "yyyy-MM-dd" in the device's local timezone.
    func dailyListeningTime(forLast days: Int, dbQueue: GRDBQueue) -> [String: Double] {
        var result: [String: Double] = [:]

        dbQueue.read { db in
            do {
                let query = """
                    SELECT date(lastPlaybackInteractionDate, 'unixepoch', 'localtime') as listenDate,
                           SUM(playedUpTo) as totalTime
                    FROM \(DataManager.episodeTableName)
                    WHERE lastPlaybackInteractionDate IS NOT NULL
                      AND lastPlaybackInteractionDate >= strftime('%s', 'now', '-\(days) days')
                    GROUP BY listenDate
                    ORDER BY listenDate ASC
                    """
                let resultSet = try db.executeQuery(query, values: nil)

                while resultSet.next() {
                    if let day = resultSet.string(forColumn: "listenDate") {
                        result[day] = resultSet.double(forColumn: "totalTime")
                    }
                }
            } catch {
                FileLog.shared.addMessage("EpisodeDataManager.dailyListeningTime error: \(error)")
            }
        }

        return result
    }

    func findLatestEpisode(podcast: Podcast, dbQueue: GRDBQueue) -> Episode? {
        loadSingle(query: "SELECT * from \(DataManager.episodeTableName) WHERE podcast_id = ? AND wasDeleted = 0 ORDER BY publishedDate DESC, addedDate DESC LIMIT 1", values: [podcast.id], dbQueue: dbQueue)
    }

    func findLatestEpisodes(podcast: Podcast, limit: Int, dbQueue: GRDBQueue) -> [Episode] {
        loadMultiple(query: "SELECT * from \(DataManager.episodeTableName) WHERE podcast_id = ? AND wasDeleted = 0 ORDER BY publishedDate DESC, addedDate DESC LIMIT ?", values: [podcast.id, limit], dbQueue: dbQueue)
    }

    func allUpNextEpisodes(dbQueue: GRDBQueue) -> [Episode] {
        let upNextTableName = DataManager.playlistEpisodeTableName
        let episodeTableName = DataManager.episodeTableName

        return loadMultiple(
            query: """
            SELECT \(episodeTableName).*
            FROM \(upNextTableName)
            JOIN \(episodeTableName)
            ON \(episodeTableName).uuid = \(upNextTableName).episodeUuid
            WHERE \(upNextTableName).playlist_id = ?
            ORDER BY \(upNextTableName).episodePosition ASC
            """,
            values: [UpNextDataManager.upNextPlaylistId],
            dbQueue: dbQueue
        )
    }

    func allUpNextEpisodes(from uuids: [String], dbQueue: GRDBQueue) -> [Episode] {
        let placeholders = uuids.map { "'\($0)'" }.joined(separator: ", ")
        let upNextTableName = DataManager.playlistEpisodeTableName
        let episodeTableName = DataManager.episodeTableName
        return loadMultiple(
            query: """
            SELECT DISTINCT \(episodeTableName).*
            FROM \(upNextTableName)
            JOIN \(episodeTableName)
            ON \(episodeTableName).uuid = \(upNextTableName).episodeUuid
            WHERE \(episodeTableName).uuid IN (\(placeholders))
            ORDER BY \(upNextTableName).episodePosition ASC
            """,
            values: nil,
            dbQueue: dbQueue
        )
    }

    private func loadSingle(query: String, values: [Any]?, dbQueue: GRDBQueue) -> Episode? {
        var episode: Episode?
        dbQueue.read { db in
            do {
                let resultSet = try db.executeQuery(query, values: values)

                if resultSet.next() {
                    episode = self.createEpisodeFrom(resultSet: resultSet)
                }
            } catch {
                FileLog.shared.addMessage("EpisodeDataManager.loadSingle error: \(error)")
            }
        }

        return episode
    }

    private func loadMultiple(query: String, values: [Any]?, dbQueue: GRDBQueue) -> [Episode] {
        var episodes = [Episode]()
        dbQueue.read { db in
            do {
                let resultSet = try db.executeQuery(query, values: values)

                while resultSet.next() {
                    if let episode = self.createEpisodeFrom(resultSet: resultSet) {
                        episodes.append(episode)
                    }
                }
            } catch {
                FileLog.shared.addMessage("EpisodeDataManager.loadMultiple Episode error: \(error)")
            }
        }

        return episodes
    }

    // MARK: - Updates

    func save(episode: Episode, dbQueue: GRDBQueue) {
        do {
            try dbQueue.dbPool.write { db in
                try insertOrSave(episode, in: db)
            }
        } catch {
            FileLog.shared.addMessage("EpisodeDataManager.save Episode error: \(error)")
        }
    }

    func bulkSave(episodes: [Episode], dbQueue: GRDBQueue) {
        do {
            try dbQueue.dbPool.write { db in
                for episode in episodes {
                    try insertOrSave(episode, in: db)
                }
            }
        } catch {
            FileLog.shared.addMessage("EpisodeDataManager.bulkSave error: \(error)")
        }
    }

    func insertMissing(episodes: [Episode], dbQueue: GRDBQueue) {
        // One write per chunk, so other writes wait for one chunk at most instead of the whole list
        for chunk in episodes.chunked(into: Constants.Limits.insertMissingChunkSize) {
            do {
                try dbQueue.dbPool.write { db in
                    let exists = try db.cachedStatement(sql: "SELECT EXISTS(SELECT 1 FROM \(DataManager.episodeTableName) WHERE uuid = ?)")
                    for episode in chunk {
                        if try Bool.fetchOne(exists, arguments: [episode.uuid]) == true { continue }
                        do {
                            episode.id = try newEpisodeId(in: db)
                            try episode.insert(db)
                        } catch {
                            episode.id = 0
                            FileLog.shared.addMessage("EpisodeDataManager.insertMissing error for \(episode.uuid): \(error)")
                        }
                    }
                }
            } catch {
                FileLog.shared.addMessage("EpisodeDataManager.insertMissing error: \(error)")
            }
        }
    }

    private func insertOrSave(_ episode: Episode, in db: Database) throws {
        if episode.id == 0 {
            episode.id = try newEpisodeId(in: db)
            try episode.insert(db)
        } else {
            try episode.save(db)
        }
    }

    private func newEpisodeId(in db: Database) throws -> Int64 {
        guard givesSequentialIds else {
            return DBUtils.generateUniqueId()
        }

        try rememberLargestEpisodeId(in: db)
        guard largestEpisodeId < Int64.max else {
            return DBUtils.generateUniqueId()
        }

        largestEpisodeId += 1
        return largestEpisodeId
    }

    private func rememberLargestEpisodeId(in db: Database) throws {
        let maxId = try Int64.fetchOne(db.cachedStatement(sql: "SELECT MAX(id) FROM \(DataManager.episodeTableName)")) ?? 0
        largestEpisodeId = max(largestEpisodeId, maxId)
    }

    func bulkSetStarred(starred: Bool, episodes: [Episode], updateSyncFlag: Bool, dbQueue: GRDBQueue) {
        if episodes.isEmpty { return }

        dbQueue.write { db in
            do {
                let firstModified = DBUtils.currentUTCTimeInMillis() + Int64(episodes.count) - 1
                for (index, episode) in episodes.enumerated() {
                    if episode.keepEpisode == starred { continue }

                    var fields = [String]()
                    var values = [Any]()

                    fields.append("keepEpisode")
                    values.append(starred)
                    if updateSyncFlag {
                        fields.append("keepEpisodeModified")
                        values.append(firstModified - Int64(index))
                    }

                    let starredModifiedValue = starred ? (firstModified - Int64(index)) : 0
                    fields.append("starredModified")
                    values.append(starredModifiedValue)

                    values.append(episode.uuid)

                    let setStatement = "SET \(fields.joined(separator: " = ?, ")) = ?"
                    try db.executeUpdate("UPDATE \(DataManager.episodeTableName) \(setStatement) WHERE uuid = ?", values: values)
                }
            } catch {
                FileLog.shared.addMessage("EpisodeDataManager.bulkSetStarred error: \(error)")
            }
        }
    }

    func bulkUserFileDelete(episodes: [Episode], dbQueue: GRDBQueue) {
        if episodes.isEmpty { return }

        dbQueue.write { db in
            do {
                for episode in episodes {
                    var fields = [String]()
                    var values = [Any]()

                    fields.append("episodeStatus")
                    values.append(DownloadStatus.notDownloaded.rawValue)
                    fields.append("autoDownloadStatus")
                    values.append(AutoDownloadStatus.userDeletedFile.rawValue)
                    fields.append("cachedFrameCount")
                    values.append(0)
                    values.append(episode.uuid)

                    let setStatement = "SET \(fields.joined(separator: " = ?, ")) = ?"
                    try db.executeUpdate("UPDATE \(DataManager.episodeTableName) \(setStatement) WHERE uuid = ?", values: values)
                }
            } catch {
                FileLog.shared.addMessage("EpisodeDataManager.bulkUserFileDelete error: \(error)")
            }
        }
    }

    func saveFileType(episode: Episode, fileType: String, dbQueue: GRDBQueue) {
        episode.fileType = fileType
        save(fieldName: "fileType", value: fileType, episodeId: episode.id, dbQueue: dbQueue)
    }

    func saveContentType(episode: Episode, contentType: String, dbQueue: GRDBQueue) {
        episode.contentType = contentType
        save(fieldName: "contentType", value: contentType, episodeId: episode.id, dbQueue: dbQueue)
    }

    func saveFileSize(episode: Episode, fileSize: Int64, dbQueue: GRDBQueue) {
        episode.sizeInBytes = fileSize
        save(fieldName: "sizeInBytes", value: fileSize, episodeId: episode.id, dbQueue: dbQueue)
    }

    func saveFrameCount(episodeId: Int64, frameCount: Int64, dbQueue: GRDBQueue) {
        save(fieldName: "cachedFrameCount", value: frameCount, episodeId: episodeId, dbQueue: dbQueue)
    }

    func findFrameCount(episodeId: Int64, dbQueue: GRDBQueue) -> Int64 {
        var frameCount = 0 as Int64

        dbQueue.read { db in
            do {
                let resultSet = try db.executeQuery("SELECT cachedFrameCount from \(DataManager.episodeTableName) WHERE id = ?", values: [episodeId])

                if resultSet.next() {
                    frameCount = resultSet.longLongInt(forColumn: "cachedFrameCount")
                }
            } catch {
                FileLog.shared.addMessage("EpisodeDataManager.findFrameCount error: \(error)")
            }
        }

        return frameCount
    }

    func saveEpisode(playbackError: String?, episode: Episode, dbQueue: GRDBQueue) {
        episode.playbackErrorDetails = playbackError
        save(fieldName: "playbackErrorDetails", value: DBUtils.replaceNilWithNull(value: episode.playbackErrorDetails), episodeId: episode.id, dbQueue: dbQueue)
    }

    func saveEpisode(playedUpTo: Double, episode: Episode, updateSyncFlag: Bool, dbQueue: GRDBQueue) {
        episode.playedUpTo = playedUpTo
        var fields = ["playedUpTo"]
        var values = [episode.playedUpTo] as [Any]

        if updateSyncFlag {
            episode.playedUpToModified = DBUtils.currentUTCTimeInMillis()
            fields.append("playedUpToModified")
            values.append(episode.playedUpToModified)
        }
        values.append(episode.id)

        save(fields: fields, values: values, dbQueue: dbQueue)
    }

    func updateEpisodePlaybackInteractionDate(episode: Episode, dbQueue: GRDBQueue) {
        let now = Date()
        let syncStatus = SyncStatus.notSynced.rawValue
        episode.lastPlaybackInteractionDate = now
        episode.lastPlaybackInteractionSyncStatus = syncStatus
        let fields = ["lastPlaybackInteractionDate", "lastPlaybackInteractionSyncStatus"]
        let values = [now, syncStatus, episode.id] as [Any]
        FileLog.shared.console("[Episode Save] Episode id \(episode.id) - title: \(episode.title ?? "no title")")
        save(fields: fields, values: values, dbQueue: dbQueue)
    }

    func clearEpisodePlaybackInteractionDate(episodeUuid: String, dbQueue: GRDBQueue) {
        save(fieldName: "lastPlaybackInteractionDate", value: NSNull(), episodeUuid: episodeUuid, dbQueue: dbQueue)
    }

    func clearAllEpisodePlaybackInteractions(dbQueue: GRDBQueue) {
        dbQueue.write { db in
            do {
                try db.executeUpdate("UPDATE \(DataManager.episodeTableName) SET lastPlaybackInteractionDate = NULL WHERE lastPlaybackInteractionDate > 0", values: [])
            } catch {
                FileLog.shared.addMessage("EpisodeDataManager.clearAllEpisodePlaybackInteractions error: \(error)")
            }
        }
    }

    func saveEpisode(playingStatus: PlayingStatus, episode: Episode, updateSyncFlag: Bool, dbQueue: GRDBQueue) {
        episode.playingStatus = playingStatus.rawValue
        var fields = ["playingStatus"]
        var values = [episode.playingStatus] as [Any]

        if updateSyncFlag {
            episode.playingStatusModified = DBUtils.currentUTCTimeInMillis()
            fields.append("playingStatusModified")
            values.append(episode.playingStatusModified)
        }
        values.append(episode.id)

        save(fields: fields, values: values, dbQueue: dbQueue)
    }

    func saveEpisode(archived: Bool, episode: Episode, updateSyncFlag: Bool, dbQueue: GRDBQueue) {
        let now = Date()
        episode.archived = archived
        episode.lastArchiveInteractionDate = now
        var fields = ["archived", "lastArchiveInteractionDate"]
        var values = [episode.archived, now] as [Any]

        if updateSyncFlag {
            episode.archivedModified = DBUtils.currentUTCTimeInMillis()
            fields.append("archivedModified")
            values.append(episode.archivedModified)
        }
        values.append(episode.id)

        save(fields: fields, values: values, dbQueue: dbQueue)
    }

    func saveEpisode(excludeFromEpisodeLimit: Bool, episode: Episode, dbQueue: GRDBQueue) {
        episode.excludeFromEpisodeLimit = excludeFromEpisodeLimit
        save(fieldName: "excludeFromEpisodeLimit", value: episode.excludeFromEpisodeLimit, episodeId: episode.id, dbQueue: dbQueue)
    }

    func saveEpisode(duration: Double, episode: Episode, updateSyncFlag: Bool, dbQueue: GRDBQueue) {
        episode.duration = duration
        var fields = ["duration"]
        var values = [episode.duration] as [Any]

        if updateSyncFlag {
            episode.durationModified = DBUtils.currentUTCTimeInMillis()
            fields.append("durationModified")
            values.append(episode.durationModified)
        }
        values.append(episode.id)

        save(fields: fields, values: values, dbQueue: dbQueue)
    }

    func saveEpisode(starred: Bool, starredModified: Int64?, episode: Episode, updateSyncFlag: Bool, dbQueue: GRDBQueue) {
        episode.keepEpisode = starred
        var fields = ["keepEpisode"]
        var values = [episode.keepEpisode] as [Any]

        fields.append("starredModified")
        if let starredModified {
            values.append(starredModified)
        } else {
            let starredModifiedValue = starred ? DBUtils.currentUTCTimeInMillis() : 0
            values.append(starredModifiedValue)
        }

        if updateSyncFlag {
            episode.keepEpisodeModified = DBUtils.currentUTCTimeInMillis()
            fields.append("keepEpisodeModified")
            values.append(episode.keepEpisodeModified)
        }
        values.append(episode.id)

        save(fields: fields, values: values, dbQueue: dbQueue)
    }

    func saveEpisode(downloadStatus: DownloadStatus, episode: Episode, dbQueue: GRDBQueue) {
        episode.episodeStatus = downloadStatus.rawValue
        save(fieldName: "episodeStatus", value: episode.episodeStatus, episodeId: episode.id, dbQueue: dbQueue)
    }

    func saveEpisode(downloadStatus: DownloadStatus, lastDownloadAttemptDate: Date, autoDownloadStatus: AutoDownloadStatus, episode: Episode, dbQueue: GRDBQueue) {
        episode.episodeStatus = downloadStatus.rawValue
        episode.lastDownloadAttemptDate = lastDownloadAttemptDate
        episode.autoDownloadStatus = autoDownloadStatus.rawValue

        let fields = ["episodeStatus", "lastDownloadAttemptDate", "autoDownloadStatus"]
        let values = [episode.episodeStatus, DBUtils.replaceNilWithNull(value: episode.lastDownloadAttemptDate), episode.autoDownloadStatus, episode.id] as [Any]

        save(fields: fields, values: values, dbQueue: dbQueue)
    }

    func saveEpisode(autoDownloadStatus: AutoDownloadStatus, episode: Episode, dbQueue: GRDBQueue) {
        episode.autoDownloadStatus = autoDownloadStatus.rawValue
        save(fieldName: "autoDownloadStatus", value: episode.autoDownloadStatus, episodeId: episode.id, dbQueue: dbQueue)
    }

    func saveEpisode(downloadStatus: DownloadStatus, downloadError: String?, downloadTaskId: String?, episode: Episode, dbQueue: GRDBQueue) {
        episode.episodeStatus = downloadStatus.rawValue
        episode.downloadErrorDetails = downloadError
        episode.downloadTaskId = downloadTaskId

        let fields = ["episodeStatus", "downloadErrorDetails", "downloadTaskId"]
        let values = [episode.episodeStatus, DBUtils.replaceNilWithNull(value: episode.downloadErrorDetails), DBUtils.replaceNilWithNull(value: episode.downloadTaskId), episode.id] as [Any]

        save(fields: fields, values: values, dbQueue: dbQueue)
    }

    func saveEpisode(downloadStatus: DownloadStatus, downloadTaskId: String?, episode: Episode, dbQueue: GRDBQueue) {
        episode.episodeStatus = downloadStatus.rawValue
        episode.downloadTaskId = downloadTaskId

        let fields = ["episodeStatus", "downloadTaskId"]
        let values = [episode.episodeStatus, DBUtils.replaceNilWithNull(value: episode.downloadTaskId), episode.id] as [Any]

        save(fields: fields, values: values, dbQueue: dbQueue)
    }

    func saveEpisode(downloadStatus: DownloadStatus, sizeInBytes: Int64, downloadTaskId: String?, episode: Episode, dbQueue: GRDBQueue) {
        episode.episodeStatus = downloadStatus.rawValue
        episode.sizeInBytes = sizeInBytes
        episode.downloadTaskId = downloadTaskId

        let fields = ["episodeStatus", "sizeInBytes", "downloadTaskId"]
        let values = [episode.episodeStatus, episode.sizeInBytes, DBUtils.replaceNilWithNull(value: episode.downloadTaskId), episode.id] as [Any]

        save(fields: fields, values: values, dbQueue: dbQueue)
    }

    func saveEpisode(downloadUrl: String, episodeUuid: String, dbQueue: GRDBQueue) {
        save(fieldName: "downloadUrl", value: downloadUrl, episodeUuid: episodeUuid, dbQueue: dbQueue)
    }

    func saveEpisode(starredModified: Int64, episodeUuid: String, dbQueue: GRDBQueue) {
        save(fieldName: "starredModified", value: starredModified, episodeUuid: episodeUuid, dbQueue: dbQueue)
    }

    func clearDownloadTaskId(episode: Episode, dbQueue: GRDBQueue) {
        save(fieldName: "downloadTaskId", value: NSNull(), episodeId: episode.id, dbQueue: dbQueue)
    }

    func delete(episodeUuid: String, dbQueue: GRDBQueue) {
        dbQueue.write { db in
            do {
                try db.executeUpdate("DELETE FROM \(DataManager.episodeTableName) WHERE uuid = ?", values: [episodeUuid])
            } catch {
                FileLog.shared.addMessage("EpisodeDataManager.delete error: \(error)")
            }
        }
    }

    func deleteAllEpisodesInPodcast(podcastId: Int64, dbQueue: GRDBQueue) {
        dbQueue.write { db in
            do {
                try db.executeUpdate("DELETE FROM \(DataManager.episodeTableName) WHERE podcast_id = ?", values: [podcastId])
            } catch {
                FileLog.shared.addMessage("EpisodeDataManager.deleteAllEpisodesInPodcast error: \(error)")
            }
        }
    }

    func markAllUnarchived(forPodcastId id: Int64, dbQueue: GRDBQueue) {
        updateAll(fields: ["archived"], values: [false, id], whereClause: "podcast_id = ?", dbQueue: dbQueue)
    }

    func bulkMarkAsPlayed(episodes: [Episode], updateSyncFlag: Bool, dbQueue: GRDBQueue) {
        if episodes.isEmpty { return }

        dbQueue.write { db in
            do {
                for episode in episodes {
                    if episode.playingStatus == PlayingStatus.completed.rawValue { continue }

                    var fields = [String]()
                    var values = [Any]()

                    fields.append("playingStatus")
                    values.append(PlayingStatus.completed.rawValue)

                    if updateSyncFlag {
                        fields.append("playingStatusModified")
                        values.append(DBUtils.currentUTCTimeInMillis())
                    }

                    values.append(episode.uuid)
                    let setStatement = "SET \(fields.joined(separator: " = ?, ")) = ?"
                    try db.executeUpdate("UPDATE \(DataManager.episodeTableName) \(setStatement) WHERE uuid = ?", values: values)
                }
            } catch {
                FileLog.shared.addMessage("EpisodeDataManager.bulkMarkAsPlayed error: \(error)")
            }
        }
    }

    func bulkMarkAsUnPlayed(episodes: [Episode], updateSyncFlag: Bool, dbQueue: GRDBQueue) {
        if episodes.isEmpty { return }

        dbQueue.write { db in
            do {
                for episode in episodes {
                    if episode.playingStatus == PlayingStatus.notPlayed.rawValue { continue }

                    var fields = [String]()
                    var values = [Any]()

                    fields.append("playingStatus")
                    values.append(PlayingStatus.notPlayed.rawValue)
                    fields.append("playedUpTo")
                    values.append(0)
                    if updateSyncFlag {
                        fields.append("playingStatusModified")
                        values.append(DBUtils.currentUTCTimeInMillis())
                    }

                    values.append(episode.uuid)
                    let setStatement = "SET \(fields.joined(separator: " = ?, ")) = ?"
                    try db.executeUpdate("UPDATE \(DataManager.episodeTableName) \(setStatement) WHERE uuid = ?", values: values)
                }
            } catch {
                FileLog.shared.addMessage("EpisodeDataManager.bulkMarkAsUnPlayed error: \(error)")
            }
        }
    }

    func bulkArchive(episodes: [Episode], markAsNotDownloaded: Bool, markAsPlayed: Bool, updateSyncFlag: Bool, dbQueue: GRDBQueue) {
        if episodes.isEmpty { return }

        dbQueue.write { db in
            do {
                for episode in episodes {
                    var fields = [String]()
                    var values = [Any]()
                    if !episode.archived {
                        fields.append("archived")
                        values.append(true)

                        if updateSyncFlag {
                            fields.append("archivedModified")
                            values.append(DBUtils.currentUTCTimeInMillis())
                        }
                    }
                    if markAsNotDownloaded, episode.episodeStatus != DownloadStatus.notDownloaded.rawValue {
                        fields.append("episodeStatus")
                        values.append(DownloadStatus.notDownloaded.rawValue)
                        fields.append("autoDownloadStatus")
                        values.append(AutoDownloadStatus.userDeletedFile.rawValue)
                        fields.append("cachedFrameCount")
                        values.append(0)
                    }
                    if markAsPlayed, episode.playingStatus != PlayingStatus.completed.rawValue {
                        fields.append("playingStatus")
                        values.append(PlayingStatus.completed.rawValue)

                        if updateSyncFlag {
                            fields.append("playingStatusModified")
                            values.append(DBUtils.currentUTCTimeInMillis())
                        }
                    }
                    if fields.isEmpty { continue }

                    values.append(episode.uuid)

                    let setStatement = "SET \(fields.joined(separator: " = ?, ")) = ?"
                    try db.executeUpdate("UPDATE \(DataManager.episodeTableName) \(setStatement) WHERE uuid = ?", values: values)
                }
            } catch {
                FileLog.shared.addMessage("EpisodeDataManager.bulkArchive error: \(error)")
            }
        }
    }

    func bulkUnarchive(episodes: [Episode], updateSyncFlag: Bool, dbQueue: GRDBQueue) {
        if episodes.isEmpty { return }

        dbQueue.write { db in
            do {
                for episode in episodes {
                    if !episode.archived { continue }

                    var fields = [String]()
                    var values = [Any]()

                    fields.append("archived")
                    values.append(false)

                    if updateSyncFlag {
                        fields.append("archivedModified")
                        values.append(DBUtils.currentUTCTimeInMillis())
                    }

                    if let podcastAutoArchiveLimit = episode.parentPodcast()?.autoArchiveEpisodeLimit, podcastAutoArchiveLimit > 0 {
                        fields.append("excludeFromEpisodeLimit")
                        values.append(true)
                    }
                    values.append(episode.uuid)
                    let setStatement = "SET \(fields.joined(separator: " = ?, ")) = ?"
                    try db.executeUpdate("UPDATE \(DataManager.episodeTableName) \(setStatement) WHERE uuid = ?", values: values)
                }
            } catch {
                FileLog.shared.addMessage("EpisodeDataManager.bulkUnarchive error: \(error)")
            }
        }
    }

    private func save(fields: [String], values: [Any], useId: Bool = true, dbQueue: GRDBQueue) {
        dbQueue.write { db in
            do {
                let setStatement = "SET \(fields.joined(separator: " = ?, ")) = ?"
                let idColumn = useId ? "id" : "uuid"
                try db.executeUpdate("UPDATE \(DataManager.episodeTableName) \(setStatement) WHERE \(idColumn) = ?", values: values)
                FileLog.shared.console("[Episode Save] \(idColumn) - \(setStatement) with values: \(values)")
            } catch {
                FileLog.shared.addMessage("EpisodeDataManager.save fields error: \(error)")
            }
        }
    }

    private func save(fieldName: String, value: Any, episodeId: Int64, dbQueue: GRDBQueue) {
        dbQueue.write { db in
            do {
                try db.executeUpdate("UPDATE \(DataManager.episodeTableName) SET \(fieldName) = ? WHERE id = ?", values: [value, episodeId])
            } catch {
                FileLog.shared.addMessage("EpisodeDataManager.save field by id error: \(error)")
            }
        }
    }

    private func save(fieldName: String, value: Any, episodeUuid: String, dbQueue: GRDBQueue) {
        dbQueue.write { db in
            do {
                try db.executeUpdate("UPDATE \(DataManager.episodeTableName) SET \(fieldName) = ? WHERE uuid = ?", values: [value, episodeUuid])
            } catch {
                FileLog.shared.addMessage("EpisodeDataManager.save field by uuid error: \(error)")
            }
        }
    }

    private func updateAll(fields: [String], values: [Any], whereClause: String?, dbQueue: GRDBQueue) {
        dbQueue.write { db in
            do {
                var query = "UPDATE \(DataManager.episodeTableName) SET \(fields.joined(separator: " = ?, ")) = ?"
                if let whereClause {
                    query += " WHERE \(whereClause)"
                }
                try db.executeUpdate(query, values: values)
            } catch {
                FileLog.shared.addMessage("EpisodeDataManager.updateAll error: \(error)")
            }
        }
    }

    // MARK: - Conversion

    private func createEpisodeFrom(resultSet rs: PCDBResultSet) -> Episode? {
        Episode.from(resultSet: rs)
    }
}


// MARK: - 👻 Ghost Episodes 👻

extension EpisodeDataManager {
    func findGhostEpisodes(_ dbQueue: GRDBQueue) -> [Episode] {
        let playlistTable = DataManager.playlistEpisodeTableName
        let query = """
        SELECT SJEpisode.*
        FROM SJEpisode
        LEFT JOIN SJPodcast ON SJEpisode.podcastUuid = SJPodcast.uuid
        LEFT JOIN \(playlistTable) ON \(playlistTable).episodeUuid = SJEpisode.uuid AND \(playlistTable).wasDeleted = 0 AND \(playlistTable).playlist_uuid IS NOT NULL
        WHERE SJPodcast.uuid IS NULL AND \(playlistTable).episodeUuid IS NULL
        """

        return loadMultiple(query: query, values: nil, dbQueue: dbQueue)
    }
}

// MARK: - Orphaned Episodes (duplicate uuid, phantom podcast_id)

extension EpisodeDataManager {
    // Distinct from findGhostEpisodes: that join is keyed on podcastUuid, so it misses rows whose
    // podcastUuid still resolves to a real podcast but whose internal podcast_id does not.
    func findOrphanedEpisodes(_ dbQueue: GRDBQueue) -> [Episode] {
        let query = """
        SELECT SJEpisode.*
        FROM SJEpisode
        LEFT JOIN SJPodcast ON SJEpisode.podcast_id = SJPodcast.id
        WHERE SJPodcast.id IS NULL
        """

        return loadMultiple(query: query, values: nil, dbQueue: dbQueue)
    }

    func deleteOrphanedEpisodes(ids: [Int64], dbQueue: GRDBQueue) {
        guard !ids.isEmpty else { return }

        dbQueue.write { db in
            let query = "DELETE FROM \(DataManager.episodeTableName) WHERE id IN (\(ids.map(String.init).joined(separator: ",")))"

            try? db.executeUpdate(query, values: nil)
        }
    }

    /// Repoints `survivorId` at `realPodcastId` and deletes `idsToDelete` in the same write, so a crash
    /// mid-migration can't commit the repoint without also removing the now-redundant duplicate row(s)
    /// (which would otherwise become permanently invisible to `findOrphanedEpisodes`).
    func reconcileOrphanedEpisode(survivorId: Int64, realPodcastId: Int64, idsToDelete: [Int64], dbQueue: GRDBQueue) {
        dbQueue.write { db in
            do {
                try db.executeUpdate("UPDATE \(DataManager.episodeTableName) SET podcast_id = ? WHERE id = ?", values: [realPodcastId, survivorId])

                if !idsToDelete.isEmpty {
                    let query = "DELETE FROM \(DataManager.episodeTableName) WHERE id IN (\(idsToDelete.map(String.init).joined(separator: ",")))"
                    try db.executeUpdate(query, values: nil)
                }
            } catch {
                FileLog.shared.addMessage("EpisodeDataManager.reconcileOrphanedEpisode error: \(error)")
            }
        }
    }
}
