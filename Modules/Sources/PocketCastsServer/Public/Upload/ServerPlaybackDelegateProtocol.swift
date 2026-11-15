import Foundation
import PocketCastsDataModel

/// What the refresh needs from the Up Next queue, to add new episodes to it
public protocol ServerPlaybackDelegate {
    func inUpNext(episode: BaseEpisode?) -> Bool
    func addToUpNext(episode: BaseEpisode, ignoringQueueLimit: Bool, toTop: Bool)
    func removeLastEpisodeFromUpNext()

    var upNextQueueCount: Int { get }
}
