import Foundation
import PocketCastsDataModel

public struct PodcastRefreshResponse: Decodable {
    public var status: String?
    public var message: String?
    public var result: RefreshResult?

    public func success() -> Bool {
        status == "ok"
    }
}

public struct RefreshResult: Decodable {
    public var podcastUpdates: [String: [RefreshEpisode]]?
}

public struct RefreshEpisode: Decodable {
    public var title: String?
    public var uuid: String?
    public var url: String?
    public var episodeDescription: String?
    public var detailedDescription: String?
    public var fileType: String?
    public var sizeInBytes: Int64?
    public var duration: TimeInterval?
    public var episodeType: String?
    public var seasonNumber: Int64?
    public var episodeNumber: Int64?
    public var publishedDate: String?
    public var alternateEnclosures: [RefreshAlternateEnclosure]?
    public var chaptersUrl: String?
    public var chaptersType: String?
    public var transcriptUrl: String?
    public var transcriptType: String?

    enum CodingKeys: String, CodingKey {
        case title
        case uuid
        case url
        case episodeDescription = "description"
        case detailedDescription = "dd"
        case fileType
        case sizeInBytes
        case duration = "durationInSecs"
        case episodeType = "epType"
        case seasonNumber = "epSeason"
        case episodeNumber = "epNumber"
        case publishedDate = "publishedAt"
        case alternateEnclosures = "alternate_enclosures"
        case chaptersUrl
        case chaptersType
        case transcriptUrl
        case transcriptType
    }

    /// The HLS stream URL from the episode's alternate enclosures, if one is present.
    /// Normalises an empty `uri` to `nil` so it isn't persisted as a bogus "missing-but-present" url.
    public var hlsUrl: String? {
        let uri = alternateEnclosures?
            .first { Episode.isHLSEnclosureType($0.type) }?
            .sources?.first?.uri
        return (uri?.isEmpty ?? true) ? nil : uri
    }
}

public struct RefreshAlternateEnclosure: Decodable {
    public struct Source: Decodable {
        public var uri: String?
    }

    public var type: String?
    public var sources: [Source]?
}

public struct PodcastInfo {
    public var uuid: String?

    public init(from searchResult: PodcastFolderSearchResult) {
        uuid = searchResult.uuid
    }
}
