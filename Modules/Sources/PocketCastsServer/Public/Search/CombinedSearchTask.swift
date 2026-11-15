import Foundation
import PocketCastsDataModel

public enum CombinedSearchResultType: Hashable {
    case episode(EpisodeSearchResult)
    case podcast(PodcastFolderSearchResult)
}

public class CombinedSearchTask {
    /// How many matching episodes a search returns
    private static let episodeLimit = 50

    public init() {}

    /// Podcasts come from Apple's podcast directory. Episodes come from the database, so only episodes of
    /// podcasts that are followed can be found.
    public func search(term: String) async throws -> [CombinedSearchResultType] {
        let podcasts = try await iTunesSearchService.shared.search(term: term)

        return podcasts.map { CombinedSearchResultType.podcast($0) } + episodes(matching: term).map { CombinedSearchResultType.episode($0) }
    }

    private func episodes(matching term: String) -> [EpisodeSearchResult] {
        let episodes = DataManager.shared.findEpisodes(matching: term, limit: Self.episodeLimit)
        guard !episodes.isEmpty else { return [] }

        let podcastTitles = DataManager.shared.allPodcasts(includeUnsubscribed: false).reduce(into: [String: String]()) { $0[$1.uuid] = $1.title }

        return episodes.map { episode in
            EpisodeSearchResult(uuid: episode.uuid,
                                title: episode.title ?? "",
                                publishedDate: episode.publishedDate ?? episode.addedDate ?? .distantPast,
                                state: episode.archived ? .archived : .normal,
                                duration: episode.duration,
                                podcastUuid: episode.podcastUuid,
                                podcastTitle: podcastTitles[episode.podcastUuid] ?? "")
        }
    }
}
