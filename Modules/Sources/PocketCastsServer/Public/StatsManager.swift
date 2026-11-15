import Foundation
import PocketCastsDataModel
import PocketCastsUtils

public class StatsManager {
    public static let shared = StatsManager()

    private struct Times {
        var savedDynamicSpeed = -1 as TimeInterval
        var savedVariableSpeed = -1 as TimeInterval
        var totalListenedTo = -1 as TimeInterval
        var totalSkipped = -1 as TimeInterval
        var savedAutoSkipping = -1 as TimeInterval
    }

    private let times = Mutex(Times())

    public init() {
        if UserDefaults.standard.object(forKey: ServerConstants.UserDefaults.statsStartDate) as? Date == nil {
            UserDefaults.standard.set(Date(), forKey: ServerConstants.UserDefaults.statsStartDate)
        }

        times.withLock { times in
            times.savedDynamicSpeed = timeForKey(ServerConstants.UserDefaults.statsDynamicSpeedSeconds)
            times.savedVariableSpeed = timeForKey(ServerConstants.UserDefaults.statsVariableSpeed)
            times.totalListenedTo = timeForKey(ServerConstants.UserDefaults.statsListenedTo)
            times.totalSkipped = timeForKey(ServerConstants.UserDefaults.statsSkipped)
            times.savedAutoSkipping = timeForKey(ServerConstants.UserDefaults.statsAutoSkip)
        }
    }

    // MARK: - dynamic speed

    public func timeSavedDynamicSpeed() -> TimeInterval {
        times.withLock { $0.savedDynamicSpeed }
    }

    public func addTimeSavedDynamicSpeed(_ seconds: TimeInterval) {
        times.withLock { times in
            times.savedDynamicSpeed += max(seconds, 0)
        }
    }

    // MARK: - variable speed

    public func timeSavedVariableSpeed() -> TimeInterval {
        times.withLock { $0.savedVariableSpeed }
    }

    public func addTimeSavedVariableSpeed(_ seconds: TimeInterval) {
        times.withLock { times in
            times.savedVariableSpeed += max(seconds, 0)
        }
    }

    // MARK: - total listened

    public func totalListeningTime() -> TimeInterval {
        times.withLock { $0.totalListenedTo }
    }

    public func addTotalListeningTime(_ seconds: TimeInterval) {
        times.withLock { times in
            times.totalListenedTo += max(seconds, 0)
        }
    }

    // MARK: - total skipped

    public func totalSkippedTime() -> TimeInterval {
        times.withLock { $0.totalSkipped }
    }

    public func addSkippedTime(_ seconds: TimeInterval) {
        times.withLock { times in
            times.totalSkipped += max(seconds, 0)
        }
    }

    // MARK: - total auto skipped

    public func totalAutoSkippedTime() -> TimeInterval {
        times.withLock { $0.savedAutoSkipping }
    }

    public func addAutoSkipTime(_ seconds: TimeInterval) {
        times.withLock { times in
            times.savedAutoSkipping += max(seconds, 0)
        }
    }

    // MARK: - General

    /**
     * To conserve battery we want to keep these stats in memory. When it makes sense to, call this
     * method to actually save them between app launches.
     */
    public func persistTimes() {
        times.withLock { times in
            saveTime(times.savedDynamicSpeed, key: ServerConstants.UserDefaults.statsDynamicSpeedSeconds)
            saveTime(times.savedVariableSpeed, key: ServerConstants.UserDefaults.statsVariableSpeed)
            saveTime(times.totalListenedTo, key: ServerConstants.UserDefaults.statsListenedTo)
            saveTime(times.totalSkipped, key: ServerConstants.UserDefaults.statsSkipped)
            saveTime(times.savedAutoSkipping, key: ServerConstants.UserDefaults.statsAutoSkip)
        }
    }

    /// When stats started being recorded, as seconds since 1970. A start date carried over from an earlier
    /// synced account takes precedence over the date stats started on this device.
    public func statsStartedAt() -> Int64 {
        let carriedOver = Int64(UserDefaults.standard.integer(forKey: ServerConstants.UserDefaults.statsStartedDateServer))
        return carriedOver > 0 ? carriedOver : Int64(statsStartDate().timeIntervalSince1970)
    }

    private func statsStartDate() -> Date {
        if let startDate = UserDefaults.standard.object(forKey: ServerConstants.UserDefaults.statsStartDate) as? Date {
            return startDate
        }

        let now = Date()
        UserDefaults.standard.set(now, forKey: ServerConstants.UserDefaults.statsStartDate)

        return now
    }

    public func timeSavedDynamicSpeedInclusive() -> TimeInterval {
        timeSavedDynamicSpeed() + timeForKey(ServerConstants.UserDefaults.statsDynamicSpeedSecondsServer)
    }

    public func timeSavedVariableSpeedInclusive() -> TimeInterval {
        timeSavedVariableSpeed() + timeForKey(ServerConstants.UserDefaults.statsVariableSpeedServer)
    }

    public func totalListeningTimeInclusive() -> TimeInterval {
        totalListeningTime() + timeForKey(ServerConstants.UserDefaults.statsListenedToServer)
    }

    public func totalSavedTime() -> TimeInterval {
        [
            totalSkippedTimeInclusive(),
            timeSavedVariableSpeedInclusive(),
            timeSavedDynamicSpeedInclusive(),
            totalAutoSkippedTimeInclusive()
        ].reduce(0, +)
    }

    public func totalSkippedTimeInclusive() -> TimeInterval {
        totalSkippedTime() + timeForKey(ServerConstants.UserDefaults.statsSkippedServer)
    }

    public func totalAutoSkippedTimeInclusive() -> TimeInterval {
        totalAutoSkippedTime() + timeForKey(ServerConstants.UserDefaults.statsAutoSkipServer)
    }

    // MARK: - Private Helpers

    private func timeForKey(_ key: String) -> TimeInterval {
        UserDefaults.standard.double(forKey: key)
    }

    private func saveTime(_ time: TimeInterval, key: String) {
        if time < 0, time < timeForKey(key) { return }

        UserDefaults.standard.set(time, forKey: key)
    }
}
