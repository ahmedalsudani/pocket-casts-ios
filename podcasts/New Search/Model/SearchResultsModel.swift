import SwiftUI
import PocketCastsServer
import PocketCastsDataModel
import PocketCastsUtils

class SearchResultsModel: ObservableObject {
    private let podcastSearch = PodcastSearchTask()
    private let combinedSearch = CombinedSearchTask()

    @Published var isSearchingForPodcasts = false

    @Published var podcastSearchError: Error?

    @Published var podcasts: [PodcastFolderSearchResult] = []
    @Published var combinedResults: [CombinedSearchResultType] = []

    @Published var isShowingLocalResultsOnly = false
    @Published var resultsContainLocalPodcasts = false

    private(set) var currentSearchTerm: String = ""

    private let dataMangager: DataManager

    let showLocalResults: Bool

    init(showLocalResults: Bool = false, dataManager: DataManager = DataManager.shared) {
        self.dataMangager = dataManager
        self.showLocalResults = showLocalResults
    }

    var noResults: Bool {
        podcasts.isEmpty && combinedResults.isEmpty
    }

    func clearSearch() {
        podcasts = []
        combinedResults = []
        resultsContainLocalPodcasts = false
        currentSearchTerm = ""
    }

    func clearErrors() {
        podcastSearchError = nil
    }

    private func isTermAnURL(_ term: String) -> Bool {
        return term.lowercased().startsWith(string: "http://") || term.lowercased().startsWith(string: "https://")
    }

    @MainActor
    func search(term: String) {
        if !isTermAnURL(term) {
            combinedSearch(term: term)
            return
        }

        currentSearchTerm = term
        clearErrors()

        if !isShowingLocalResultsOnly {
            clearSearch()
        }

        Task {
            isSearchingForPodcasts = true
            do {
                let results = try await podcastSearch.search(term: term)
                show(podcastResults: results)
            } catch {
                podcastSearchError = error
            }

            isSearchingForPodcasts = false
        }
    }

    @MainActor
    func combinedSearch(term: String) {
        currentSearchTerm = term
        clearErrors()

        if !isShowingLocalResultsOnly {
            clearSearch()
        }

        Task {
            isSearchingForPodcasts = true
            do {
                let results = try await combinedSearch.search(term: term)
                showCombinedResults(results)
            } catch {
                podcastSearchError = error
            }

            isSearchingForPodcasts = false
        }
    }

    @MainActor
    func searchLocally(term searchTerm: String) {
        clearSearch()

        let allPodcasts = dataMangager.allPodcasts(includeUnsubscribed: false)

        var results = [PodcastFolderSearchResult?]()
        for podcast in allPodcasts {
            guard let title = podcast.title else { continue }

            if title.localizedCaseInsensitiveContains(searchTerm) {
                results.append(PodcastFolderSearchResult(from: podcast))
            } else if let author = podcast.author, author.localizedCaseInsensitiveContains(searchTerm) {
                results.append(PodcastFolderSearchResult(from: podcast))
            }
        }

        let allFolders = dataMangager.allFolders()
        for folder in allFolders {
            if folder.name.localizedCaseInsensitiveContains(searchTerm) {
                results.append(PodcastFolderSearchResult(from: folder))
            }
        }

        self.podcasts = results.compactMap { $0 }

        resultsContainLocalPodcasts = true
        isShowingLocalResultsOnly = true
    }

    private func show(podcastResults: [PodcastFolderSearchResult]) {
        if isShowingLocalResultsOnly {
            podcasts.append(contentsOf: podcastResults.filter { !podcasts.contains($0) })
            isShowingLocalResultsOnly = false
        } else {
            podcasts = podcastResults
        }
    }

    private func showCombinedResults(_ results: [CombinedSearchResultType]) {
        combinedResults = results
    }
}
