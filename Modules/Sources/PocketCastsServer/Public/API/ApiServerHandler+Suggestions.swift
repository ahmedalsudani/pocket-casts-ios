import Foundation

extension ApiServerHandler {
    /// Suggested folders are server-curated. Returning nil makes the UI fall
    /// through to its empty / hidden state.
    public func suggestedFolders(for uuids: [String], language: String = Locale.current.language.languageCode?.identifier ?? "en") async -> SuggestedFoldersResponse? {
        nil
    }
}
