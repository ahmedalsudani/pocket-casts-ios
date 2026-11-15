import Foundation
import PocketCastsDataModel
import PocketCastsServer
import PocketCastsUtils

struct UserInfo {
    struct Stats {
        /// The total number of podcasts the user is subscribed to
        let podcastCount: Int

        /// The total time the user has listened to podcasts
        let listeningTime: Stat

        /// The total time the user has saved from playback effects
        let savedTime: Stat

        init() {
            podcastCount = DataManager.shared.podcastCount()
            listeningTime = .init(seconds: StatsManager.shared.totalListeningTimeInclusive())
            savedTime = .init(seconds: StatsManager.shared.totalSavedTime())
        }

        struct Stat {
            let seconds: TimeInterval
            let formatValues: Double.TimeFormatValueType

            init(seconds: TimeInterval) {
                self.seconds = seconds
                formatValues = seconds.timeFormatValues
            }
        }
    }
}
