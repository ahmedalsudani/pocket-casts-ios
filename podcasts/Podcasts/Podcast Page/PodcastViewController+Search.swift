import Foundation
import PocketCastsDataModel

extension PodcastViewController {
    func performEpisodeSearch(query: String) {
        guard let podcast else { return }

        // Episode search used to run on the cache server; every episode of
        // the podcast is in the local database now, so search there instead.
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let matchingUuids = DataManager.sharedManager.findEpisodes(with: query, podcastUUID: podcast.uuid).map(\.uuid)

            DispatchQueue.main.async {
                self?.showSearchResults(matchingUuids, podcastUuid: podcast.uuid)
            }
        }
    }

    private func showSearchLoading() {}

    func showSearchResults(_ matchingUuids: [String], podcastUuid: String) {
        searchController?.searchDidComplete()

        guard let podcast, podcast.uuid == podcastUuid else { return }

        uuidsThatMatchSearch = matchingUuids

        loadLocalEpisodes(podcast: podcast, animated: true)
    }
}
