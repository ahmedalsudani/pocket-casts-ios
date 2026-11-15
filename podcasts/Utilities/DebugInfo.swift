import Foundation
import PocketCastsUtils

struct DebugInfo {
    private static func formattedFreeDiskSpace() -> String {
        guard let documentURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
              let values = try? documentURL.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]),
              let capacity = values.volumeAvailableCapacityForImportantUsage else {
            return "Unknown"
        }
        return capacity.formatted(.byteCount(style: .file))
    }

    static func string() -> String {
        let now = Date()
        let localTime = DateFormatHelper.shared.localTimeJsonDateFormatter.string(from: now)
        let gmtTime = DateFormatHelper.shared.jsonFormat(now)

        return """
        App Version: \(Settings.appVersion())
        Device: \(DeviceUtil.identifier)
        OS: \(DeviceUtil.systemVersion ?? "Unknown")
        Local Time: \(localTime)
        UTC Time: \(gmtTime)
        Watch App Installed: \(WatchManager.shared.isWatchAppInstalled ? "yes" : "no")
        Free Disk Space: \(formattedFreeDiskSpace())

        Auto Download On: \(Settings.autoDownloadEnabled() ? "yes" : "no")
        Auto Download Only on Wifi: \(Settings.autoDownloadMobileDataAllowed() ? "no" : "yes")
        Warn Before Using Data: \(Settings.mobileDataAllowed() ? "no" : "yes")
        Auto Download Up Next:  \(Settings.downloadUpNextEpisodes ? "yes" : "no")
        Auto Archive Played Episodes after: \(ArchiveHelper.archiveTimeToText(Settings.autoArchivePlayedAfter()))
        Auto Archive Inactive Episodes after: \(ArchiveHelper.archiveTimeToText(Settings.autoArchiveInactiveAfter()))
        Auto Archive Starred Episodes: \(Settings.archiveStarredEpisodes())
        """
    }
}
