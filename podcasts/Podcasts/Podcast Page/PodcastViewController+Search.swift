import Foundation
import PocketCastsDataModel

extension PodcastViewController {
    func setupSearchController() {
        let controller = EpisodeListSearchController()
        controller.placeholder = L10n.searchEpisodes
        controller.searchDebounce = Settings.episodeSearchDebounceTime()
        controller.delegate = self

        addChild(controller)
        controller.didMove(toParent: self)
        searchController = controller

        updateSearchHeader()
    }

    /// Updates the episode count and the archived button of the search header
    func updateSearchHeader(uuidsToFilter: [String]? = nil) {
        guard let searchController, let podcast else { return }

        let hasEpisodeLimit = (podcast.autoArchiveEpisodeLimit > 0 && podcast.overrideGlobalArchive)
        let count = episodeCount(uuidsToFilter: uuidsToFilter)

        let infoText = (count == 1 ? L10n.podcastEpisodeCountSingular : L10n.podcastEpisodeCountPluralFormat(count.localized())) + " • "
        let info = NSMutableAttributedString(string: infoText, attributes: [.foregroundColor: AppTheme.colorForStyle(.primaryText02)])
        if hasEpisodeLimit {
            info.append(NSAttributedString(string: L10n.podcastEpisodeLimitCountFormat(podcast.autoArchiveEpisodeLimit.localized()), attributes: [.foregroundColor: AppTheme.colorForStyle(.support08)]))
        } else {
            info.append(NSAttributedString(string: L10n.podcastArchivedCountFormat(archivedEpisodeCount(uuidsToFilter: uuidsToFilter).localized()), attributes: [.foregroundColor: AppTheme.colorForStyle(.primaryText02)]))
        }

        searchController.info = info
        searchController.actionTitle = showingArchived() ? L10n.podcastHideArchived : L10n.podcastShowArchived
    }

    func performEpisodeSearch(query: String) {
        guard let podcast else { return }

        // Every episode of the podcast is in the database, so that's where the search runs
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let matchingUuids = DataManager.shared.findEpisodes(with: query, podcastUUID: podcast.uuid).map(\.uuid)

            DispatchQueue.main.async {
                self?.showSearchResults(matchingUuids, podcastUuid: podcast.uuid)
            }
        }
    }

    private func showSearchResults(_ matchingUuids: [String], podcastUuid: String) {
        searchController?.isLoading = false

        guard let podcast, podcast.uuid == podcastUuid else { return }

        uuidsThatMatchSearch = matchingUuids
        loadLocalEpisodes(podcast: podcast, animated: true)
    }
}

// MARK: - EpisodeListSearchControllerDelegate

extension PodcastViewController: EpisodeListSearchControllerDelegate {
    func episodeListSearchController(_ controller: EpisodeListSearchController, didChangeSearchTerm searchTerm: String) {
        searchEpisodes(query: searchTerm)
    }

    func episodeListSearchController(_ controller: EpisodeListSearchController, didSubmitSearchTerm searchTerm: String) {
        searchEpisodes(query: searchTerm)
    }

    func episodeListSearchControllerDidBeginEditing(_ controller: EpisodeListSearchController) {
        didActivateSearch()
    }

    func episodeListSearchControllerDidTapAction(_ controller: EpisodeListSearchController) {
        toggleShowArchived()
    }

    func episodeListSearchControllerDidTapOverflow(_ controller: EpisodeListSearchController) {
        showEpisodeOptions()
    }
}
