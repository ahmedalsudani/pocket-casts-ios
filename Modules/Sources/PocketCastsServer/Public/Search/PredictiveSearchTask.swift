import Foundation

struct PredictiveSearchEnvelope: Decodable {
    public let results: [PredictiveSearchResult]
}

public struct PredictivePodcastSearchResult: Codable, Hashable {
    public let uuid: String
    let title: String
    let author: String
}

public enum PredictiveSearchResultType: Hashable {
    case unknown(String)
    case term(String)
    case podcast(PredictivePodcastSearchResult)
}

public struct PredictiveSearchResult: Decodable, Hashable {
    public let type: PredictiveSearchResultType

    enum CodingKeys: String, CodingKey {
        case type
        case value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
            case "term":
                let value = try container.decode(String.self, forKey: .value)
                self.type = .term(value)
            case "podcast":
                let podcast = try container.decode(PredictivePodcastSearchResult.self, forKey: .value)
                self.type = .podcast(podcast)
            default:
                let value = try container.decode(String.self, forKey: .value)
                self.type = .unknown(value)
        }
    }
}

public class PredictiveSearchTask {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    /// Predictive search ran against `search.pocketcasts.com/autocomplete`.
    /// Returns an empty list now — the search UI just won't show
    /// autocomplete suggestions. The main `PodcastSearchTask` (iTunes) still
    /// works on submit.
    public func search(term: String) async throws -> [PredictiveSearchResult] {
        []
    }
}
