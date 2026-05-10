import Foundation
import PocketCastsUtils

/// Show notes / episode metadata used to come from
/// `cache.pocketcasts.com/mobile/show_notes/full/{uuid}`. With the cache server
/// gone, the show notes that LocalFeedService already extracts from the RSS
/// feed (`<description>` / `<content:encoded>`) are now the source of truth —
/// see `ShowInfoCoordinator`. This retriever is preserved as a no-op so the
/// existing call sites compile.
public actor ShowInfoDataRetriever {

    public init() {}

    public func loadEpisodeDataFromCache(
        for podcastUuid: String,
        episodeUuid: String,
        useCacheOnly: Bool = false
    ) async throws -> String? {
        nil
    }

    public func loadShowInfoData(
        for podcastUuid: String
    ) async throws -> Data {
        throw TaskError.nilSelf
    }
}

public enum TaskError: Error {
    case nilSelf
}
