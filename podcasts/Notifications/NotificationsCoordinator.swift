import Foundation
import PocketCastsUtils
import PocketCastsServer
import PocketCastsDataModel
import UserNotifications

enum NotificationType: String {

    case onboardingImport
    case onboardingThemes
    case onboardingUpNext
    case onboardingFilters

    case reengagementWeekly
    case reengagementDownloads

    var title: String {
        switch self {
        case .onboardingImport:
            return L10n.notificationsOnboardingImportTitle
        case .onboardingThemes:
            return L10n.notificationsOnboardingThemesTitle
        case .onboardingUpNext:
            return L10n.notificationsOnboardingUpnextTitle
        case .onboardingFilters:
            return L10n.notificationsOnboardingFiltersTitle
        case .reengagementWeekly:
            return L10n.notificationsReengagementWeeklyTitle
        case .reengagementDownloads:
                return L10n.notificationsReengagementDownloadsTitle
        }
    }

    var body: String {
        switch self {
        case .onboardingImport:
            return L10n.notificationsOnboardingImportBody
        case .onboardingThemes:
            return L10n.notificationsOnboardingThemesBody
        case .onboardingUpNext:
            return L10n.notificationsOnboardingUpnextBody
        case .onboardingFilters:
            return L10n.notificationsOnboardingFiltersBody
        case .reengagementWeekly:
            return L10n.notificationsReengagementWeeklyBody
        case .reengagementDownloads:
                return L10n.notificationsReengagementDownloadsBody(NotificationsCoordinator.shared.numberOfDownloadsAvailable())
        }
    }

    var identifier: String {
        return self.rawValue
    }

    var link: String {
        switch self {
        case .onboardingImport:
            return "pktc://settings/import"
        case .onboardingThemes:
            return "pktc://settings/themes"
        case .onboardingUpNext:
            return "pktc://upnext/?location=tab"
        case .onboardingFilters:
            return "pktc://filters"
        case .reengagementWeekly:
            return "pktc://discover"
        case .reengagementDownloads:
            return "pktc://profile/downloads"
        }
    }

    var shouldSend: Bool {
        if !self.isRepeatable, Settings.notificationsLastTriggerDate[self.rawValue] != nil {
            return false
        }
        switch self {
            case .reengagementDownloads:
                return NotificationsCoordinator.shared.numberOfDownloadsAvailable() > 0
            default:
                return true
        }
    }

    var isRepeatable: Bool {
        switch self {
            case .reengagementWeekly,
                 .reengagementDownloads:
                return true
            default:
                return false
        }
    }
}

enum NotificationsGroup: CaseIterable {

    case newEpisodes
    case dailyReminders
    case newFeaturesAndTips

    var notifications: [NotificationType] {
        switch self {
            case .newEpisodes:
                return [] // New episode notifications are raised by `NewEpisodeNotificationScheduler` when a refresh finds episodes
            case .dailyReminders:
                return [.onboardingImport, .onboardingUpNext, .onboardingFilters, .onboardingThemes]
            case .newFeaturesAndTips:
                return [.reengagementWeekly, .reengagementDownloads]
        }
    }

    var scheduleHour: Int {
        switch self {
            case .newEpisodes:
                return 0 // Sent when a refresh finds new episodes, not on a schedule
            case .dailyReminders:
                return 10
            case .newFeaturesAndTips:
                return 16
        }
    }

    var isEnabled: Bool {
        switch self {
            case .newEpisodes:
                return Settings.notificationsNewEpisodes
            case .dailyReminders:
                return Settings.notificationsDailyReminders
            case .newFeaturesAndTips:
                return Settings.notificationsNewFeaturesAndTips
        }
    }

    func setEnabled(_ newValue: Bool) {
        switch self {
            case .newEpisodes:
                if newValue {
                    // the user has just turned on push, enable it for all their podcasts for simplicity
                    DataManager.shared.setPushForAllPodcasts(pushEnabled: true)
                    NotificationsHelper.shared.registerForPushNotifications()
                } else {
                    RefreshManager.shared.refreshPodcasts(forceEvenIfRefreshedRecently: true)
                }
                Settings.notificationsNewEpisodes = newValue
            case .dailyReminders:
                Settings.notificationsDailyReminders = newValue
            case .newFeaturesAndTips:
                Settings.notificationsNewFeaturesAndTips = newValue
        }
    }

    var timeIntervalStep: TimeInterval {
        switch self {
            case .newEpisodes:
                return 0
            case .dailyReminders:
                return 24.hours
            case .newFeaturesAndTips:
                return 1.week
        }
    }

    func trigger(order: Int, notification: NotificationType) -> UNNotificationTrigger? {
        let calendar = Calendar.current
        switch self {
            case .newEpisodes:
                return nil
            case .dailyReminders:
                let timeIntervalToSchedule: TimeInterval = calculateTimeIntervalToHour(scheduleHour)
                return UNTimeIntervalNotificationTrigger(timeInterval: timeIntervalToSchedule + (Double(order) * timeIntervalStep), repeats: notification.isRepeatable)
            case .newFeaturesAndTips:
                return makeTrigger(
                    days: (order + 1) * 2,
                    from: .now,
                    calendar: calendar,
                    repeats: notification.isRepeatable
                )
        }
    }

    private func makeTrigger(days: Int, from date: Date = .now, calendar: Calendar, repeats: Bool) -> UNCalendarNotificationTrigger? {
        guard let fireDate = calendar.date(byAdding: .day, value: days, to: date) else {
            return nil
        }

        let weekday = calendar.component(.weekday, from: fireDate)
        let components = DateComponents(hour: scheduleHour, weekday: weekday)
        return UNCalendarNotificationTrigger(dateMatching: components, repeats: repeats)
    }

    static var allDisabled: Bool {
        Self.allCases.allSatisfy() {
            $0.isEnabled == false
        }
    }

    private func calculateTimeIntervalToHour(_ hour: Int) -> TimeInterval {
        guard let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date.now, matchingPolicy: .nextTime),
              let nextDate = Calendar.current.date(byAdding: .day, value: 1, to: date)
        else {
            return 0
        }
        return nextDate.timeIntervalSince(Date.now)
    }
}

class NotificationsCoordinator {

    static let shared = NotificationsCoordinator()

    private let notificationCenter: UNUserNotificationCenter

    private init(notificationCenter: UNUserNotificationCenter = .current()) {
        self.notificationCenter = notificationCenter
    }

    @discardableResult
    func requestAndSetupInitialPermissions() async -> Bool {
        await withCheckedContinuation { continuation in
            NotificationsHelper.shared.registerForPushNotifications() { granted in
                guard granted else {
                    continuation.resume(returning: false)
                    return
                }
                // Only activate all groups for a fresh setup; if the user already configured notifications, leave their per-group/per-podcast settings untouched.
                if NotificationsGroup.allDisabled {
                    for group in NotificationsGroup.allCases {
                        self.setupNotifications(for: group)
                    }
                }
                continuation.resume(returning: granted)
            }
        }
    }

    func setupNotifications(for group: NotificationsGroup) {
        group.setEnabled(true)
        NotificationsHelper.shared.enablePush()
        NotificationsHelper.shared.registerForPushNotifications { [weak self] granted in
            guard let self, granted else { return }
            updateNotifications(for: group)
        }
    }

    func updateNotifications(for group: NotificationsGroup) {
        cancelNotifications(for: group)
        var order = 0
        for notification in group.notifications {
            guard notification.shouldSend,
                  let trigger = group.trigger(order: order, notification: notification)
            else {
                continue
            }
            scheduleNotification(notification, trigger: trigger)
            order += 1
        }
    }

    func disableNotifications(for group: NotificationsGroup) {
        group.setEnabled(false)
        cancelNotifications(for: group)
        if NotificationsGroup.allDisabled {
            NotificationsHelper.shared.disablePush()
        }
    }

    func scheduleNotification(_ type: NotificationType, trigger: UNNotificationTrigger) {
        let content = UNMutableNotificationContent()
        content.title = type.title
        content.body = type.body
        content.categoryIdentifier = NotificationsHelper.NotificationsCategory.deepLink.rawValue
        content.userInfo = ["destination_url": type.link]

        let request = UNNotificationRequest(identifier: type.identifier, content: content, trigger: trigger)

        // Schedule the request with the system.
        Task {
            do {
                try await notificationCenter.add(request)
            } catch {
                // Handle errors that may occur during add.
                FileLog.shared.addMessage("[Notifications Coordinator] Error adding notification: \(error)")
            }
        }
    }

    func markNotification(_ notification: NotificationType) {
        var notificationDates = Settings.notificationsLastTriggerDate
        notificationDates[notification.rawValue] = Date.now
        Settings.notificationsLastTriggerDate = notificationDates
    }

    func cancelNotifications(for group: NotificationsGroup) {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: group.notifications.map { $0.identifier })
    }

    func cancelNotification(_ type: NotificationType) {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [type.identifier])
    }

    private lazy var episodesDataManager: EpisodesDataManager = {
        return EpisodesDataManager()
    }()

    func numberOfDownloadsAvailable() -> Int {
        episodesDataManager.downloadedEpisodes().reduce(0) { partialResult, list in
            return partialResult + list.elements.count
        }
    }
}
