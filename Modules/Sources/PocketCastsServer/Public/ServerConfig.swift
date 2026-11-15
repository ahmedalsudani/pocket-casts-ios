import Foundation
import PocketCastsDataModel

public class ServerConfig {
    public static let shared = ServerConfig()

    // MARK: - App values required by the refresh

    public var syncDelegate: ServerSyncDelegate?
    public var playbackDelegate: ServerPlaybackDelegate?
}
