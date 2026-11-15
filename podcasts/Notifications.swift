import Foundation

extension NSNotification.Name {
    /// When the episode artwork is loaded
    static let episodeEmbeddedArtworkLoaded = NSNotification.Name(rawValue: "PCEpisodeEmbeddedArtworkLoaded")

    static let tableViewReorderWillBegin = NSNotification.Name("TableView.ReorderWillBegin")
    static let tableViewReorderDidEnd = NSNotification.Name("TableView.ReorderDidEnd")
}
