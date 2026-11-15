import SwiftUI
import PocketCastsServer

struct SearchResultsView: View {
    @EnvironmentObject var theme: Theme
    @EnvironmentObject var searchResults: SearchResultsModel

    @State var displayMode: SearchDisplayMode = .allResults

    var body: some View {
        Group {
            if searchResults.podcastSearchError != nil && !searchResults.resultsContainLocalPodcasts {
                HStack(alignment: .center) {
                    EmptyStateView(
                        title: L10n.discoverSearchFailed,
                        message: L10n.discoverSearchFailedMsg,
                        icon: { Image("no-connection-grey").renderingMode(.template) },
                        actions: [
                            .init(title: L10n.tryAgain, style: SimpleTextButtonStyle(theme: .shared, textColor: .primaryInteractive01)) {
                                searchResults.search(term: searchResults.currentSearchTerm)
                            }
                        ]
                    )
                }
                .frame(maxHeight: .infinity)
                .background(Theme.shared.searchBackground)
            } else if searchResults.isSearchingForPodcasts {
                  ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .tint(AppTheme.loadingActivityColor.color)
            } else if searchResults.noResults {
                HStack(alignment: .center) {
                    EmptyStateView(title: L10n.searchResultsEmptyTitle,
                                   message: L10n.searchResultsEmptyMessage,
                                   icon: { Image("search") },
                                   actions: []
                    )
                }
                .frame(maxHeight: .infinity)
                .background(Theme.shared.searchBackground)
            } else {
                VStack(spacing: 0) {
                    if searchResults.combinedResults.count > 1 {
                        filterPicker
                    }
                    List {
                        if displayMode == .allResults || displayMode == .podcasts {
                            localResults
                        }
                        combinedList
                    }
                    .scrollDismissesKeyboard(.immediately)
                    .listStyle(.plain)
                    .listRowSeparatorTint(theme.primaryUi05)
                    .scrollContentBackground(.hidden)
                    .ignoresSafeArea(.keyboard, edges: .bottom)
                }
            }
        }
        .background(theme.searchBackground.ignoresSafeArea())
    }

    @ViewBuilder var filterPicker: some View {
        PillSegmentControl(SearchDisplayMode.allCases, selection: $displayMode) { item in
            Text(item.localizedDescription)
        }
        .padding(.bottom, 8)
        .background(LiquidGlass.isEnabled ? theme.searchBackground : theme.secondaryUi01)
        .onChange(of: displayMode) { _, newValue in
        }
    }

    var filteredResults: [CombinedSearchResultType] {
        let podcastsUuids = searchResults.podcasts.map({ result in
            result.uuid
        })
        switch displayMode {
            case .allResults:
                return searchResults.combinedResults.filter { result in
                    switch result {
                        case .podcast(let podcast):
                            return !podcastsUuids.contains(podcast.uuid)
                        default:
                            return true
                    }
                }
            case .episodes:
                return searchResults.combinedResults.filter { result in
                    if case .episode = result {
                        return true
                    } else {
                        return false
                    }
                }
            case .podcasts:
                return searchResults.combinedResults.filter { result in
                    if case let .podcast(podcast) = result {
                        return !podcastsUuids.contains(podcast.uuid)
                    } else {
                        return false
                    }
                }
        }
    }

    @ViewBuilder var combinedList: some View {
        ForEach(filteredResults, id: \.self) { result in
            switch result {
                case .podcast(let podcast):
                    SearchResultCell(episode: nil, result: podcast, played: false, showDivider: false, cellStyle: ListCellButtonStyle(backgroundStyle: .searchBackground))
                        .listRowBackground(theme.searchBackground)
                        .alignmentGuide(.listRowSeparatorLeading) { _ in
                            return 0
                        }
                case .episode(let episode):
                    SearchResultCell(episode: episode, result: nil, showDivider: false, cellStyle: ListCellButtonStyle(backgroundStyle: .searchBackground))
                        .listRowBackground(theme.searchBackground)
                        .alignmentGuide(.listRowSeparatorLeading) { _ in
                            return 0
                        }
            }
        }
    }

    @ViewBuilder var localResults: some View {
        ForEach(searchResults.podcasts, id: \.self) { localPodcast in
            SearchResultCell(episode: nil, result: localPodcast, played: false, showDivider: false, cellStyle: ListCellButtonStyle(backgroundStyle: .searchBackground))
                .listRowBackground(theme.searchBackground)
                .alignmentGuide(.listRowSeparatorLeading) { _ in
                    return 0
                }
        }
    }
}

/// Under Liquid Glass, search uses the standard list background to match other list
/// screens; the legacy appearance keeps the original `primaryUi01`.
private extension ThemeStyle {
    static var searchBackground: ThemeStyle {
        LiquidGlass.isEnabled ? .primaryUi02 : .primaryUi01
    }
}

private extension Theme {
    var searchBackground: Color {
        AppTheme.color(for: .searchBackground, theme: self)
    }
}

struct SearchResultsView_Previews: PreviewProvider {
    static var previews: some View {
        SearchResultsView()
            .previewWithAllThemes()
    }
}
