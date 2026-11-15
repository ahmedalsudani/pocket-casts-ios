import Foundation

public enum ServerNotifications {
    // Refresh
    public static let podcastsRefreshed = NSNotification.Name(rawValue: "PCRefreshed")
    public static let podcastRefreshFailed = NSNotification.Name(rawValue: "PCRefFailed")
    public static let podcastRefreshThrottled = NSNotification.Name(rawValue: "PCRefreshedThrottled")
    public static let episodeTypeOrLengthChanged = NSNotification.Name(rawValue: "SJEpisodeTypeChanged")

    /// Posted after a refresh inserts new episodes for podcasts that have
    /// notifications enabled. The notification `object` is a
    /// `[NewEpisodeNotificationInfo]`, from which the app schedules local notifications.
    public static let newEpisodesDetected = NSNotification.Name(rawValue: "PCNewEpisodesDetected")
}

/// Payload for `ServerNotifications.newEpisodesDetected`: one entry per newly
/// added episode belonging to a podcast with notifications enabled.
public struct NewEpisodeNotificationInfo {
    public let podcastTitle: String
    public let episodeUuid: String
    public let episodeTitle: String

    public init(podcastTitle: String, episodeUuid: String, episodeTitle: String) {
        self.podcastTitle = podcastTitle
        self.episodeUuid = episodeUuid
        self.episodeTitle = episodeTitle
    }
}
