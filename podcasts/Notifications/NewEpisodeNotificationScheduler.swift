import Foundation
import PocketCastsServer
import UserNotifications

/// Schedules local notifications for new episodes found during a refresh.
///
/// Episode notifications used to arrive as pushes from the Pocket Casts
/// server; with refresh running on-device the server can't tell us anymore,
/// so this listens for `ServerNotifications.newEpisodesDetected` (posted by
/// the refresh pipeline for podcasts with notifications turned on) and raises
/// equivalent local notifications. The payload matches what the old pushes
/// carried (`userInfo["eu"]` + the episode category), so the existing tap and
/// action handling in `NotificationsHelper` works unchanged.
class NewEpisodeNotificationScheduler {
    /// A refresh after a long time away can find dozens of episodes; don't flood the user.
    private static let maxNotificationsPerRefresh = 10

    init() {
        NotificationCenter.default.addObserver(self, selector: #selector(newEpisodesDetected(_:)), name: ServerNotifications.newEpisodesDetected, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func newEpisodesDetected(_ notification: Notification) {
        guard NotificationsHelper.shared.pushEnabled(), let episodes = notification.object as? [NewEpisodeNotificationInfo] else { return }

        for episode in episodes.prefix(Self.maxNotificationsPerRefresh) {
            let content = UNMutableNotificationContent()
            content.title = episode.podcastTitle
            content.body = episode.episodeTitle
            content.sound = .default
            content.categoryIdentifier = NotificationsHelper.NotificationsCategory.episodes.rawValue
            content.userInfo = ["eu": episode.episodeUuid]

            let request = UNNotificationRequest(identifier: "newEpisode-\(episode.episodeUuid)", content: content, trigger: nil)
            UNUserNotificationCenter.current().add(request)
        }
    }
}
