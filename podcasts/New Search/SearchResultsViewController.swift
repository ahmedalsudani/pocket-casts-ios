import Foundation
import SwiftUI
import PocketCastsUtils

protocol SearchResultsDelegate {
    func clearSearch()
    func performLocalSearch(searchTerm: String)
    func performSearch(searchTerm: String, triggeredByTimer: Bool, completion: @escaping (() -> Void))
}

extension SearchResultsDelegate {
    func performSearch(searchTerm: String, triggeredByTimer: Bool, completion: @escaping (() -> Void)) {}
}

class SearchResultsViewController: UIHostingController<AnyView> {
    private let displaySearch = SearchVisibilityModel()
    private let searchHistoryModel = SearchHistoryModel.shared
    private let searchResults: SearchResultsModel

    init(showLocalResults: Bool = false) {
        self.searchResults = SearchResultsModel(showLocalResults: showLocalResults)
        super.init(rootView: AnyView(
            SearchView()
            .setupDefaultEnvironment()
            .environmentObject(searchResults)
            .environmentObject(searchHistoryModel)
            .environmentObject(displaySearch))
        )
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

}

extension SearchResultsViewController: SearchResultsDelegate {
    func clearSearch() {
        displaySearch.isSearching = false
        searchResults.clearSearch()
    }

    func performLocalSearch(searchTerm: String) {
        displaySearch.isSearching = true
        searchResults.searchLocally(term: searchTerm)
    }

    func performSearch(searchTerm: String, triggeredByTimer: Bool, completion: @escaping (() -> Void)) {
        displaySearch.isSearching = true
        if searchTerm.trim().isEmpty {
            completion()
        }

        searchResults.search(term: searchTerm)

        if !triggeredByTimer, !searchTerm.trim().isEmpty {
            searchHistoryModel.add(searchTerm: searchTerm)
        }

        completion()
    }
}
