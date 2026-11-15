import Combine
import Foundation
import SwiftUI

import PocketCastsDataModel
import PocketCastsServer
import PocketCastsUtils

class PodcastHeaderViewModel: NSObject, ObservableObject {

    @Published var podcast: Podcast

    private(set) weak var delegate: PodcastActionsDelegate?

    init(podcast: Podcast, delegate: PodcastActionsDelegate? = nil) {
        self.podcast = podcast
        self.delegate = delegate
        self.isSubscribed = podcast.isSubscribed()
        _isExpanded =  Published(initialValue: delegate?.isSummaryExpanded() ?? false)
        super.init()
        addObservers()
    }

    @Published var isExpanded: Bool = true

    @Published var isSubscribed: Bool = false

    private var cancellables = Set<AnyCancellable>()
    private func addObservers() {
        NotificationCenter.default.publisher(for: Constants.Notifications.podcastUpdated)
        .receive(on: OperationQueue.main)
        .sink { [unowned self] notification in
            guard let podcastUuid = notification.object as? String,
                  podcastUuid == podcast.uuid,
                  let podcast = DataManager.shared.findPodcast(uuid: podcastUuid, includeUnsubscribed: true)
            else {
                return
            }
            self.podcast = podcast
            self.isSubscribed = podcast.isSubscribed()
        }
        .store(in: &cancellables)
    }

    var folderImage: String {
        (podcast.folderUuid?.isEmpty ?? true) ? "folder-empty" : "folder-check"
    }

    /// The category and author line
    var displayCategoryAndAuthor: String {
        let category = podcast.podcastCategory?.localized(seperatingWith: \.isNewline) ?? ""
        guard let author = podcast.author else { return category }

        return category + " · " + author
    }

    var displayAuthor: String? {
        guard let podcastAuthor = podcast.author else {
            return nil
        }
        return podcastAuthor
    }

    var displayWebsite: String? {
        guard let websiteUrl = podcast.podcastUrl, let host = URL(string: websiteUrl)?.host else {
            return nil
        }
        if host.startsWith(string: "www.") {
            let wwwIndex = host.index(host.startIndex, offsetBy: 4)
            return String(host[wwwIndex...])
        } else {
            return host
        }
    }

    var displayFrequency: String? {
        guard let frequency = podcast.displayableFrequency() else {
            return nil
        }
        return L10n.paidPodcastReleaseFrequencyFormat(frequency)
    }

    var displayNextEpisodeDate: String? {
        guard let estimatedDate = podcast.displayableNextEpisodeDate() else {
            return nil
        }
        return L10n.paidPodcastNextEpisodeFormat(estimatedDate)
    }

    func subscribeButtonTapped() {
        guard let delegate else { return }

        if podcast.isSubscribed() || isSubscribed {
            delegate.unsubscribe()
            // do not switch variable here because there is still a confimation screen
        } else {
            delegate.subscribe()
            // switching state immediately so animation is triggered at press
            isSubscribed = true
        }
    }

    func websiteLinkTapped() {
        guard let website = podcast.podcastUrl, let url = URL(string: website) else { return }
        delegate?.open(url: url)
    }

    func toggleExpanded() {
        let willBeExpanded = !isExpanded
        delegate?.setSummaryExpanded(expanded: willBeExpanded)
        isExpanded.toggle()
    }

    var htmlDescription: String {
        return podcast.podcastHTMLDescription ?? podcast.podcastDescription ?? ""
    }

    func podcastArtworkTapped() {
        delegate?.refreshArtwork()
    }
}

extension PodcastHeaderViewModel: ExpandableLabelDelegate {
    // MARK: - ExpandableLabelDelegate

    func willExpandLabel(_ label: UIView) {
        delegate?.tableView().beginUpdates()
    }

    func didExpandLabel(_ label: UIView) {
        delegate?.tableView().endUpdates()
    }

    func willCollapseLabel(_ label: UIView) {
        delegate?.tableView().beginUpdates()
    }

    func didCollapseLabel(_ label: UIView) {
        delegate?.tableView().endUpdates()
    }

    func linkTapped(url: URL) {
        delegate?.open(url: url)
    }
}
