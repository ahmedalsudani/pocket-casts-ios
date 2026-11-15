import Foundation
import Combine
import PocketCastsServer
import PocketCastsDataModel

/// Represents a view that will display the listening stats
class ProfileDataViewModel: ObservableObject {

    // Allow UIKit to update to view size changes
    private(set) var contentSize: CGSize? = nil
    var viewContentSizeChanged: (() -> Void)? = nil

    /// Listening Stats
    var stats: UserInfo.Stats = .init()

    private var notifications = Set<AnyCancellable>()

    init() {
        update()

        // Listen for the refresh event to update the view
        NotificationCenter.default
            .publisher(for: ServerNotifications.podcastsRefreshed)
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] _ in self?.update() })
            .store(in: &notifications)
    }

    /// Refresh the store data
    func update() {
        stats = .init()

        objectWillChange.send()
    }

    func contentSizeChanged(_ size: CGSize) {
        contentSize = size
        viewContentSizeChanged?()
    }
}
