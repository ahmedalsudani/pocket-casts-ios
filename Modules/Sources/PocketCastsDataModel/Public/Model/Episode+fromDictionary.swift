import Foundation
import PocketCastsUtils

extension Episode {
    /// MIME type we advertise for HLS streams we send elsewhere, e.g. to Google Cast.
    public static let advertisedHLSMimeType = "application/x-mpegURL"

    /// HLS content types we accept and play as video. Stored lowercased, so lookups must lowercase their input too.
    public static let hlsEnclosureTypes = Set([
        "application/x-mpegurl",
        "application/mpegurl",
        "application/vnd.apple.mpegurl"
    ].map { $0.lowercased() })

    /// Whether an `alternate_enclosures` type string advertises an HLS stream.
    public static func isHLSEnclosureType(_ type: String?) -> Bool {
        guard let type else { return false }
        return hlsEnclosureTypes.contains(type.lowercased())
    }

    /// Extracts the HLS stream URL from a feed episode's `alternate_enclosures` array, if one is present.
    ///
    /// The structure looks like:
    /// ```
    /// "alternate_enclosures": [
    ///   { "type": "application/x-mpegURL", "sources": [ { "uri": "https://.../file.m3u8" } ] }
    /// ]
    /// ```
    public static func hlsUrl(fromEpisodeJson episodeJson: [String: Any]) -> String? {
        guard let alternateEnclosures = episodeJson["alternate_enclosures"] as? [[String: Any]] else {
            return nil
        }

        let hlsEnclosure = alternateEnclosures.first { isHLSEnclosureType($0["type"] as? String) }
        let sources = hlsEnclosure?["sources"] as? [[String: Any]]
        return sources?.first?["uri"] as? String
    }

    public static func from(episodeJson: [String: Any], podcastId: Int64, podcastUuid: String) -> Episode {
        let episode = Episode()
        episode.addedDate = Date()
        episode.podcast_id = podcastId
        episode.podcastUuid = podcastUuid
        episode.playingStatus = PlayingStatus.notPlayed.rawValue
        episode.episodeStatus = DownloadStatus.notDownloaded.rawValue
        if let uuid = episodeJson["uuid"] as? String {
            episode.uuid = uuid
        }
        if let title = episodeJson["title"] as? String {
            episode.title = title
        }
        if let url = episodeJson["url"] as? String {
            episode.downloadUrl = url
        }
        if let fileType = episodeJson["file_type"] as? String {
            episode.fileType = fileType
        }
        if let fileSize = episodeJson["file_size"] as? Int64 {
            episode.sizeInBytes = fileSize
        }
        if let duration = episodeJson["duration"] as? Double {
            episode.duration = duration
        }
        if let publishedStr = episodeJson["published"] as? String {
            episode.publishedDate = ISO8601DateParser.date(from: publishedStr)
        }
        if let number = episodeJson["number"] as? Int64 {
            episode.episodeNumber = number
        }
        if let season = episodeJson["season"] as? Int64 {
            episode.seasonNumber = season
        }
        if let type = episodeJson["type"] as? String {
            episode.episodeType = type
        }
        if let description = episodeJson["description"] as? String {
            episode.episodeDescription = description
        }
        if let descriptionHTML = episodeJson["description_html"] as? String {
            episode.detailedDescription = descriptionHTML
        }
        if let chaptersUrl = episodeJson["chapters_url"] as? String {
            episode.chaptersUrl = chaptersUrl
        }
        if let chaptersType = episodeJson["chapters_type"] as? String {
            episode.chaptersType = chaptersType
        }
        if let transcriptUrl = episodeJson["transcript_url"] as? String {
            episode.transcriptUrl = transcriptUrl
        }
        if let transcriptType = episodeJson["transcript_type"] as? String {
            episode.transcriptType = transcriptType
        }

        episode.hlsUrl = hlsUrl(fromEpisodeJson: episodeJson)

        return episode
    }
}
