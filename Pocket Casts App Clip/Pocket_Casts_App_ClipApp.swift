import SwiftUI
import PocketCastsServer

@main
struct Pocket_Casts_App_ClipApp: App {

    @UIApplicationDelegateAdaptor private var appDelegate: AppClipAppDelegate

    init() {
        ServerConfig.shared.syncDelegate = ServerSyncManager.shared
        ServerConfig.shared.playbackDelegate = PlaybackManager.shared

        ServerSettings.setSkipBackTime(10, syncChange: false)
        ServerSettings.setSkipForwardTime(45, syncChange: false)
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                NowPlayingView()
                    .background(Color(UIColor.systemBackground))
            }
        }
    }
}
