import Foundation

@testable import PocketCastsDataModel

class DataManagerMock: DataManager {
    var podcastsToReturn: [Podcast] = []
    var dailyListeningTimeToReturn: [String: Double] = [:]

    override func allPodcasts(includeUnsubscribed: Bool) -> [Podcast] {
        return podcastsToReturn
    }

    override func dailyListeningTime(forLast days: Int = 365) -> [String: Double] {
        return dailyListeningTimeToReturn
    }
}
