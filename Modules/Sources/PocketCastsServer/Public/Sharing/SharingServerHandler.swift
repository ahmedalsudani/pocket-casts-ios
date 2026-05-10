import Foundation

public class SharingServerHandler {
    private static let timeout: TimeInterval = 20

    public static let shared = SharingServerHandler()

    public struct PodcastShareInfo: Codable {
        public let title: String
        public let description: String?
        public let podcasts: [String]

        public init(title: String, description: String, podcasts: [String]) {
            self.title = title
            self.description = description
            self.podcasts = podcasts
        }
    }

    public struct PodcastList: Decodable {
        public let title: String?
        public let listDescription: String?
        public let podcasts: [ListPodcast]?

        public enum CodingKeys: String, CodingKey {
            case title, podcasts
            case listDescription = "description"
        }
    }

    public struct ListPodcast: Decodable {
        public let title: String?
        public let uuid: String?
        public let podcastDescription: String?
        public let author: String?
        public let iTunesId: Int?

        public enum CodingKeys: String, CodingKey {
            case title, uuid, author
            case podcastDescription = "description"
            case iTunesId = "collection_id"
        }
    }

    private lazy var securityDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMddHHmmss"

        return formatter
    }()

    private struct PodcastShareRequest: Codable {
        let title: String
        let description: String?
        let podcasts: [[String: String]]

        var datetime: String?
        var h: String?
    }

    private struct PodcastShareResponse: Decodable {
        var status: String?
        var result: PodcastShareResult?
    }

    private struct PodcastShareResult: Decodable {
        var shareUrl: String?

        enum CodingKeys: String, CodingKey {
            case shareUrl = "share_url"
        }
    }

    public func sharePodcastList(listInfo: PodcastShareInfo, completion: @escaping (_ shareUrl: String?) -> Void) {
        completion(nil)
    }

    public func loadList(listUrl: URL, completion: @escaping (_ podcastList: PodcastList?) -> Void) {
        completion(nil)
    }
}
