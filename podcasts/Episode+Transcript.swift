import Foundation
import PocketCastsDataModel
import PocketCastsUtils

extension Episode {
    func checkTranscriptAvailability() {
        Task {
            if let transcripts = try? await ShowInfoCoordinator.shared.loadTranscriptsMetadata(podcastUuid: parentIdentifier(), episodeUuid: uuid) {
                let userInfo: [String: Any] = [
                    "episodeUuid": uuid,
                    "isAvailable": !transcripts.isEmpty
                ]
                NotificationCenter.postOnMainThread(notification: Constants.Notifications.episodeTranscriptAvailabilityChanged, userInfo: userInfo)
            }
        }
    }
}
