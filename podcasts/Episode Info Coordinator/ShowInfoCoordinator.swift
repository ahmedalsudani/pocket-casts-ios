import Foundation
import PocketCastsDataModel
import PocketCastsServer
import PocketCastsUtils

actor ShowInfoCoordinator: ShowInfoCoordinating {
    static let shared = ShowInfoCoordinator()

    /// Shown in place of show notes when an episode's feed entry had none
    static let noShowNotesMessage = "Unable to find show notes for this episode."

    private let podcastIndexChapterRetriever: PodcastIndexChapterDataRetriever
    private let dataManager: DataManager

    init(
        podcastIndexChapterRetriever: PodcastIndexChapterDataRetriever = PodcastIndexChapterDataRetriever(),
        dataManager: DataManager = .shared
    ) {
        self.podcastIndexChapterRetriever = podcastIndexChapterRetriever
        self.dataManager = dataManager
    }

    func loadShowNotes(
        podcastUuid: String,
        episodeUuid: String
    ) async throws -> String {
        let metadata = try await loadShowInfo(podcastUuid: podcastUuid, episodeUuid: episodeUuid)
        return metadata?.showNotes ?? Self.noShowNotesMessage
    }

    func loadEpisodeArtworkUrl(
        podcastUuid: String,
        episodeUuid: String
    ) async throws -> URL? {
        let metadata = try await loadShowInfo(podcastUuid: podcastUuid, episodeUuid: episodeUuid)
        return metadata?.image.flatMap(URL.init(string:))
    }

    public func loadChapters(
        podcastUuid: String,
        episodeUuid: String
    ) async throws -> ([Episode.Metadata.EpisodeChapter]?, [PodcastIndexChapter]?) {
        let metadata = try await loadShowInfo(podcastUuid: podcastUuid, episodeUuid: episodeUuid)

        if let podcastIndexChapterUrl = metadata?.chaptersUrl,
           let chapters = try? await podcastIndexChapterRetriever.loadChapters(podcastIndexChapterUrl) {
            return (nil, chapters.chapters)
        }

        if let chapters = metadata?.chapters, !chapters.isEmpty {
            return (chapters, nil)
        }

        return (nil, nil)
    }

    public func loadTranscriptsMetadata(podcastUuid: String, episodeUuid: String) async throws -> [Episode.Metadata.Transcript] {
#if os(watchOS)
        return []
#else
        let metadata = try await loadShowInfo(podcastUuid: podcastUuid, episodeUuid: episodeUuid)
        return metadata?.transcripts ?? []
#endif
    }

    @discardableResult
    func loadShowInfo(
        podcastUuid: String,
        episodeUuid: String
    ) async throws -> Episode.Metadata? {
        try await requestShowInfo(podcastUuid: podcastUuid, episodeUuid: episodeUuid)
    }

    /// Builds episode metadata from the episode's database row: descriptions and Podcasting 2.0
    /// chapter/transcript URLs are captured from the feed when it's read and stored on the episode.
    @discardableResult
    func requestShowInfo(
        podcastUuid: String,
        episodeUuid: String
    ) async throws -> Episode.Metadata? {
        guard let episode = dataManager.findEpisode(uuid: episodeUuid) else { return nil }

        let showNotes = episode.detailedDescription?.isEmpty == false
            ? episode.detailedDescription
            : episode.episodeDescription

        var transcripts = [Episode.Metadata.Transcript]()
        if let transcriptUrl = episode.transcriptUrl, let transcriptType = episode.transcriptType {
            transcripts = [Episode.Metadata.Transcript(url: transcriptUrl, type: transcriptType, language: nil)]
        }

        return Episode.Metadata(
            showNotes: showNotes,
            chaptersUrl: episode.chaptersUrl,
            transcripts: transcripts
        )
    }
}
