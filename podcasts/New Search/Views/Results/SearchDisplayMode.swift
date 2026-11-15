import Foundation

enum SearchDisplayMode: String, CaseIterable, Identifiable {
    case allResults
    case podcasts
    case episodes

    var id: String {
        rawValue
    }

    var localizedDescription: String {
        switch self {
            case .allResults:
                return L10n.allResults
            case .podcasts:
                return L10n.podcastsPlural
            case .episodes:
                return L10n.episodes
        }
    }
}
