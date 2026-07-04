import Foundation
import PocketCastsDataModel
import PocketCastsServer
import PocketCastsUtils

actor ShowInfoCoordinator: ShowInfoCoordinating {
    static let shared = ShowInfoCoordinator()

    private let podcastIndexChapterRetriever: PodcastIndexChapterDataRetriever
    private let dataManager: DataManager

    init(
        podcastIndexChapterRetriever: PodcastIndexChapterDataRetriever = PodcastIndexChapterDataRetriever(),
        dataManager: DataManager = .sharedManager
    ) {
        self.podcastIndexChapterRetriever = podcastIndexChapterRetriever
        self.dataManager = dataManager
    }

    func loadShowNotes(
        podcastUuid: String,
        episodeUuid: String
    ) async throws -> String {
        let metadata = try await loadShowInfo(podcastUuid: podcastUuid, episodeUuid: episodeUuid)
        return metadata?.showNotes ?? CacheServerHandler.noShowNotesMessage
    }

    func loadEpisodeArtworkUrl(
        podcastUuid: String,
        episodeUuid: String
    ) async throws -> String? {
        let metadata = try await loadShowInfo(podcastUuid: podcastUuid, episodeUuid: episodeUuid)
        return metadata?.image
    }

    public func loadChapters(
        podcastUuid: String,
        episodeUuid: String
    ) async throws -> ([Episode.Metadata.EpisodeChapter]?, [PodcastIndexChapter]?) {
        let metadata = try await loadShowInfo(podcastUuid: podcastUuid, episodeUuid: episodeUuid)

        if let pocastIndexChapterUrl = metadata?.chaptersUrl,
            let chapters = try? await podcastIndexChapterRetriever.loadChapters(pocastIndexChapterUrl) {
            return (nil, chapters.chapters)
        }

        return (metadata?.chapters, nil)
    }

    private func buildGeneratedTranscript(podcastUuid: String, episodeUuid: String) -> Episode.Metadata.Transcript {
        let format = TranscriptFormat.vtt
        let urlString = "\(ServerConstants.Urls.generatedTranscripts)\(podcastUuid)/\(episodeUuid).\(format.fileExtension)"
        return Episode.Metadata.Transcript(url: urlString, type: format.rawValue, language: nil)
    }

    public func loadTranscriptsMetadata(podcastUuid: String, episodeUuid: String) async throws -> EpisodeTranscriptData {
#if os(watchOS)
        return (transcripts: [], hasGeneratedTranscripts: false)
#else
        let metadata = try await loadShowInfo(podcastUuid: podcastUuid, episodeUuid: episodeUuid)

        if FeatureFlag.generatedTranscripts.enabled {
            let externalTranscripts = metadata?.transcripts ?? []
            var pocketCastsTranscripts: [Episode.Metadata.Transcript] = []
            if let episode = dataManager.findEpisode(uuid: episodeUuid),
               let hasTranscript = episode.hasGeneratedTranscript {
                if hasTranscript {
                    let transcript = buildGeneratedTranscript(podcastUuid: podcastUuid, episodeUuid: episodeUuid)
                    pocketCastsTranscripts = [transcript]
                }
            } else {
                pocketCastsTranscripts = metadata?.pocketCastsTranscripts ?? []
            }

            let transcripts = externalTranscripts.isEmpty ? pocketCastsTranscripts : externalTranscripts
            return (transcripts: transcripts, hasGeneratedTranscripts: !pocketCastsTranscripts.isEmpty)
        }

        guard let transcripts = metadata?.transcripts else {
            return (transcripts: [], hasGeneratedTranscripts: false)
        }
        return (transcripts: transcripts, hasGeneratedTranscripts: false)
#endif
    }

    @discardableResult
    func loadShowInfo(
        podcastUuid: String,
        episodeUuid: String
    ) async throws -> Episode.Metadata? {
        try await requestShowInfo(podcastUuid: podcastUuid, episodeUuid: episodeUuid)
    }

    /// Builds episode metadata from the local database row. The cache server
    /// that used to supply this JSON is gone — descriptions and Podcasting 2.0
    /// chapter/transcript URLs are captured from the RSS feed at
    /// subscribe/refresh time and stored on the episode.
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
