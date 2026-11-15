import Foundation

extension NotificationsCoordinator {
    /// Things that happen in the app that the scheduled reminders react to
    enum AppEvent {
        case applicationOpened
        case applicationClosed
        case importShown
        case themeChanged
        case addedToUpNext
        case filterCreated
        case downloadsShown
    }

    /// Cancels the reminders an event makes pointless, and reschedules the ones it resets.
    func handle(_ event: AppEvent) {
        DispatchQueue.main.async { [self] in
            updateDailyReminders(for: event)
            updateReEngagementNotifications(for: event)
        }
    }

    private func updateDailyReminders(for event: AppEvent) {
        guard NotificationsGroup.dailyReminders.isEnabled else {
            return
        }
        for notification in NotificationsGroup.dailyReminders.notifications where notification.isCancelled(by: event) {
            markNotification(notification)
            cancelNotification(notification)
        }
    }

    private func updateReEngagementNotifications(for event: AppEvent) {
        guard NotificationsGroup.newFeaturesAndTips.isEnabled else {
            return
        }
        for notification in NotificationsGroup.newFeaturesAndTips.notifications where notification.isCancelled(by: event) {
            cancelNotification(notification)
        }

        if event == .applicationClosed {
            updateNotifications(for: .newFeaturesAndTips)
        }
    }
}

private extension NotificationType {
    func isCancelled(by event: NotificationsCoordinator.AppEvent) -> Bool {
        switch self {
        case .reengagementWeekly:
            return event == .applicationOpened
        case .onboardingImport:
            return event == .importShown
        case .onboardingThemes:
            return event == .themeChanged
        case .onboardingUpNext:
            return event == .addedToUpNext
        case .onboardingFilters:
            return event == .filterCreated
        case .reengagementDownloads:
            return event == .downloadsShown
        }
    }
}
