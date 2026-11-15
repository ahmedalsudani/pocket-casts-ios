import XCTest
@testable import podcasts
@testable import PocketCastsDataModel

final class PlaybackQueueTests: XCTestCase {

    func testOverrideAllEpisodesWithClearsUpNext() {
        let playbackQueue = PlaybackQueue()
        let mockDataManager = MockDataManager()
        DataManager.shared = mockDataManager

        let queuedEpisode = PlaylistEpisode()
        queuedEpisode.episodeUuid = "queued-uuid"
        queuedEpisode.title = "Queued Episode"
        mockDataManager.upNextEpisodes = [queuedEpisode]

        let newEpisode = UserEpisode()
        newEpisode.uuid = "current-uuid"
        newEpisode.title = "Current Episode"

        playbackQueue.overrideAllEpisodesWith(episode: newEpisode)

        XCTAssertTrue(mockDataManager.deleteCalled, "Should clear Up Next before playing the new episode")
    }

    func testReorderUpNextPersistsNewOrderAndKeepsMissingEntriesAtBottom() {
        let playbackQueue = PlaybackQueue()
        let mockDataManager = MockDataManager()
        DataManager.shared = mockDataManager

        // Position 0 is the now playing episode, which stays pinned and isn't reordered.
        mockDataManager.upNextEpisodes = [
            playlistEpisode(uuid: "now-playing", position: 0),
            playlistEpisode(uuid: "a", position: 1),
            playlistEpisode(uuid: "b", position: 2),
            playlistEpisode(uuid: "missing", position: 3) // no matching episode in sortedEpisodes
        ]

        // Desired new order for the known episodes.
        playbackQueue.reorderUpNext(sortedEpisodes: [episode("b"), episode("a")])

        let savedUuids = mockDataManager.savedPlaylistEpisodes.map { $0.episodeUuid }
        let savedPositions = mockDataManager.savedPlaylistEpisodes.map { $0.episodePosition }

        // The known episodes follow the sorted order, the missing entry sinks to the bottom...
        XCTAssertEqual(savedUuids, ["b", "a", "missing"])
        // ...and positions start at 1 since position 0 is reserved for the now playing episode.
        XCTAssertEqual(savedPositions, [1, 2, 3])
    }

    func testReorderUpNextDoesNothingWithFewerThanTwoSortedEpisodes() {
        let playbackQueue = PlaybackQueue()
        let mockDataManager = MockDataManager()
        DataManager.shared = mockDataManager

        mockDataManager.upNextEpisodes = [
            playlistEpisode(uuid: "now-playing", position: 0),
            playlistEpisode(uuid: "a", position: 1)
        ]

        playbackQueue.reorderUpNext(sortedEpisodes: [episode("a")])

        XCTAssertTrue(mockDataManager.savedPlaylistEpisodes.isEmpty, "Reordering one episode should be a no-op")
    }

    private func playlistEpisode(uuid: String, position: Int32) -> PlaylistEpisode {
        let playlistEpisode = PlaylistEpisode()
        playlistEpisode.episodeUuid = uuid
        playlistEpisode.episodePosition = position
        return playlistEpisode
    }

    private func episode(_ uuid: String) -> Episode {
        let episode = Episode()
        episode.uuid = uuid
        return episode
    }
}

fileprivate class MockDataManager: DataManager {
    var savedPlaylistEpisodes: [PlaylistEpisode] = []
    var upNextEpisodes: [PlaylistEpisode] = []
    var deleteCalled = false

    override func allUpNextPlaylistEpisodes() -> [PlaylistEpisode] {
        return upNextEpisodes
    }

    override func save(playlistEpisodes: [PlaylistEpisode]) {
        savedPlaylistEpisodes = playlistEpisodes
    }

    override func deleteAllUpNextEpisodes() {
        deleteCalled = true
        upNextEpisodes.removeAll()
    }
}
