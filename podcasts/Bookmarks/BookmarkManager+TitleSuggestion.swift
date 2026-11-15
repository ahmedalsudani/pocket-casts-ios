import Foundation
import PocketCastsDataModel
import PocketCastsUtils

extension BookmarkManager {

    static var isTitleSuggestionEnabled: Bool {
        FeatureFlag.smartBookmarks.enabled
    }

    /// The transcript passage the bookmark's title is generated from: the one it was created with.
    ///
    /// Returns nil when suggestions are disabled or the bookmark wasn't made from a transcript.
    func transcriptSnippet(for bookmark: Bookmark, episode: BaseEpisode) async -> BookmarkTranscriptSnippet? {
        guard Self.isTitleSuggestionEnabled else {
            return nil
        }

        // Let the on-device model load while the transcript is fetched.
        prewarmTitleGeneration()

        // Only a bookmark made from a transcript selection has a passage to work from. A publisher's
        // transcript is timed against its own copy of the audio, which dynamic ads shift away from,
        // so the bookmark's time alone can't be trusted to find the right words.
        return await capturedSnippet(for: bookmark, episode: episode)
    }

    func capturedSnippet(for bookmark: Bookmark, episode: BaseEpisode) async -> BookmarkTranscriptSnippet? {
        guard Self.isTitleSuggestionEnabled, let passage = bookmark.passage, !passage.isEmpty else {
            return nil
        }

        return await BookmarkTranscriptSnippetExtractor().snippet(forPassage: passage, at: bookmark.passageLocation, episode: episode)
    }

    /// Returns nil when generation fails.
    func suggestTitle(from snippet: String, for bookmark: Bookmark, episode: BaseEpisode) async -> String? {
        let podcastTitle = bookmark.podcastUuid.flatMap { DataManager.shared.findPodcast(uuid: $0)?.title }
        do {
            let title = try await generateTitle(transcriptSnippet: snippet, podcastTitle: podcastTitle, episodeTitle: episode.title)

            guard !Task.isCancelled else {
                return nil
            }

            return title
        } catch {
            FileLog.shared.addMessage("[Bookmarks] Title suggestion failed: \(error)")
            return nil
        }
    }
}
