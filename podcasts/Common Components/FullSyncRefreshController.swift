import Foundation
import PocketCastsServer

/// Owns a `CustomRefreshControl` and wires it up to a refresh of every followed podcast:
/// triggers `RefreshManager.shared.refreshPodcasts()` on pull, and observes
/// the resulting notifications to update the status text and dismiss the control
/// when the refresh finishes.
///
/// The owner is responsible for assigning `refreshControl` to a scroll view.
final class FullSyncRefreshController {
    let refreshControl = CustomRefreshControl()

    init() {
        refreshControl.perform = { [weak self] _ in
            self?.beginRefreshing()
        }

        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(podcastsRefreshed), name: ServerNotifications.podcastsRefreshed, object: nil)
        center.addObserver(self, selector: #selector(podcastRefreshFailed), name: ServerNotifications.podcastRefreshFailed, object: nil)
        center.addObserver(self, selector: #selector(podcastsRefreshed), name: Constants.Notifications.opmlImportCompleted, object: nil)
        center.addObserver(self, selector: #selector(podcastsRefreshed), name: ServerNotifications.podcastRefreshThrottled, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func beginRefreshing() {
        refreshControl.set(text: L10n.refreshControlFetchingEpisodes)
        RefreshManager.shared.refreshPodcasts()
    }

    @objc private func podcastsRefreshed() {
        finishRefreshing(message: L10n.refreshControlRefreshComplete)
    }

    @objc private func podcastRefreshFailed() {
        finishRefreshing(message: L10n.refreshControlRefreshFailed)
    }

    private func finishRefreshing(message: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self, self.refreshControl.isRefreshing else { return }
            self.refreshControl.set(text: message)
            self.refreshControl.endRefreshing()
        }
    }
}
