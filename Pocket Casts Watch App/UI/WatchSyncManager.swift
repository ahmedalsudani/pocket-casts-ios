import Foundation
import PocketCastsDataModel
import PocketCastsServer
import PocketCastsUtils

class WatchSyncManager {
    static let shared = WatchSyncManager()

    func setup() {
        ServerConfig.shared.syncDelegate = self
        ServerConfig.shared.playbackDelegate = PlaybackManager.shared

        performUpdateIfRequired(updateKey: "CreatedDefPlaylistsV2") {
            PlaylistManager.createDefaultPlaylists()
        }

        performUpdateIfRequired(updateKey: "FirstRunDefaults") {
            // these are considered defaults for a new app install
            ServerSettings.setSkipBackTime(10)
            ServerSettings.setSkipForwardTime(45)

            Settings.setAutoArchivePlayedAfter(0)
            Settings.setAutoArchiveInactiveAfter(-1)
            Settings.setArchiveStarredEpisodes(false)

            Settings.setShouldDeleteWhenPlayed(true)
            Settings.setMobileDataAllowed(true)
        }
    }

    private func performUpdateIfRequired(updateKey: String, update: () -> Void) {
        if UserDefaults.standard.bool(forKey: updateKey) { return } // already performed this update

        update()
        UserDefaults.standard.set(true, forKey: updateKey)
    }
}
