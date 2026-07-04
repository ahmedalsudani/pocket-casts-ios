import Foundation
import PocketCastsDataModel
import PocketCastsUtils

public struct ParsedFeed {
    public let title: String?
    public let author: String?
    public let description: String?
    public let descriptionHTML: String?
    public let imageURL: String?
    public let link: String?
    public let category: String?
    public let language: String?
    public let funding: String?
    public let episodes: [ParsedEpisode]
}

public struct ParsedEpisode {
    public let guid: String
    /// Stable UUID v5 derived from the feed URL plus the item's GUID, suitable
    /// for the existing Pocket Casts data model where episodes are keyed by
    /// UUID. Scoping to the feed URL keeps episodes from different podcasts
    /// distinct even when their feeds reuse the same GUIDs (e.g. "1", "2").
    /// Like the podcast-level UUID, this keys on the exact feed URL string, so
    /// the same feed reached via a different URL yields a different identity.
    public let uuid: String
    public let title: String?
    public let downloadURL: String?
    public let description: String?
    public let descriptionHTML: String?
    public let publishedDate: Date?
    public let durationSeconds: Double?
    public let sizeInBytes: Int64?
    public let fileType: String?
    public let episodeNumber: Int64?
    public let seasonNumber: Int64?
    public let episodeType: String?
    public let chaptersURL: String?
    public let chaptersType: String?
    public let transcriptURL: String?
    public let transcriptType: String?
}

public enum LocalFeedFetchResult {
    case success(feed: ParsedFeed, lastModified: String?, etag: String?)
    case notModified
}

public enum LocalFeedFetchError: Error {
    case invalidResponse
    case parseFailed
    case httpError(Int)
}

public class LocalFeedService {
    public static let shared = LocalFeedService()

    private let connection: URLConnection

    public init(connection: URLConnection = URLConnection(handler: URLSession.shared)) {
        self.connection = connection
    }

    public func fetch(feedURL: URL, lastModified: String? = nil, etag: String? = nil) async throws -> LocalFeedFetchResult {
        var request = URLRequest(url: feedURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
        request.httpMethod = "GET"
        if let lastModified {
            request.setValue(lastModified, forHTTPHeaderField: ServerConstants.HttpHeaders.ifModifiedSince)
        }
        if let etag {
            request.setValue(etag, forHTTPHeaderField: ServerConstants.HttpHeaders.ifNoneMatch)
        }
        request.setValue("application/rss+xml, application/atom+xml, application/xml;q=0.9, */*;q=0.8", forHTTPHeaderField: ServerConstants.HttpHeaders.accept)
        request.setValue(ServerConstants.Values.appUserAgent, forHTTPHeaderField: ServerConstants.HttpHeaders.userAgent)

        let (data, response) = try await connection.send(request: request)

        let http = response as? HTTPURLResponse
        if let status = http?.statusCode {
            if status == ServerConstants.HttpConstants.notModified {
                return .notModified
            }
            if status < 200 || status >= 300 {
                throw LocalFeedFetchError.httpError(status)
            }
        }

        guard let data else { throw LocalFeedFetchError.invalidResponse }

        let parser = FeedXMLParser(feedURLString: feedURL.absoluteString)
        guard let feed = parser.parse(data: data) else { throw LocalFeedFetchError.parseFailed }

        return .success(
            feed: feed,
            lastModified: http?.value(forHTTPHeaderField: ServerConstants.HttpHeaders.lastModified),
            etag: http?.value(forHTTPHeaderField: ServerConstants.HttpHeaders.etag)
        )
    }

    /// Fans out a refresh across all subscribed podcasts that have a stored
    /// feed URL (in `Podcast.podcastUrl`). Failures on individual feeds are
    /// logged and skipped — they don't fail the overall response.
    public func refresh(podcasts: [Podcast]) async -> PodcastRefreshResponse {
        var podcastUpdates: [String: [RefreshEpisode]] = [:]

        await withTaskGroup(of: (String, [RefreshEpisode]).self) { group in
            for podcast in podcasts {
                guard let urlString = podcast.podcastUrl, let url = URL(string: urlString) else {
                    FileLog.shared.addMessage("LocalFeedService: skipping podcast \(podcast.uuid) — no feed URL stored")
                    continue
                }
                let podcastUuid = podcast.uuid
                group.addTask { [weak self] in
                    guard let self else { return (podcastUuid, []) }
                    do {
                        let result = try await self.fetch(feedURL: url, lastModified: podcast.lastUpdatedAt)
                        switch result {
                        case .notModified:
                            return (podcastUuid, [])
                        case .success(let feed, _, _):
                            return (podcastUuid, feed.refreshEpisodes())
                        }
                    } catch {
                        FileLog.shared.addMessage("LocalFeedService: refresh failed for \(podcastUuid): \(error.localizedDescription)")
                        return (podcastUuid, [])
                    }
                }
            }

            for await (uuid, episodes) in group where !episodes.isEmpty {
                podcastUpdates[uuid] = episodes
            }
        }

        var response = PodcastRefreshResponse()
        response.status = "ok"
        var refreshResult = RefreshResult()
        refreshResult.podcastUpdates = podcastUpdates
        response.result = refreshResult
        return response
    }

    /// Look up an iTunes podcast by its iTunes Id and return its RSS feed URL,
    /// using Apple's iTunes Search API. The Pocket Casts server is not involved.
    public func iTunesLookup(iTunesId: Int) async throws -> URL? {
        guard let url = URL(string: "https://itunes.apple.com/lookup?id=\(iTunesId)&entity=podcast") else {
            return nil
        }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: ServerConstants.HttpHeaders.accept)

        let (data, _) = try await connection.send(request: request)
        guard let data,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = json["results"] as? [[String: Any]],
              let feedUrl = results.first?["feedUrl"] as? String else {
            return nil
        }
        return URL(string: feedUrl)
    }
}

extension ParsedFeed {
    /// Builds the JSON-shaped dictionary that `Podcast.from(podcastJson:)` and
    /// the existing `ServerPodcastManager.addPodcast(podcastInfo:...)` flow
    /// already understand, so on-device feed parsing stays a drop-in for the
    /// old cache-server response.
    public func toPodcastInfoJson(uuid: String, feedURLString: String) -> [String: Any] {
        var podcastJson: [String: Any] = [
            "uuid": uuid,
            "url": feedURLString
        ]
        if let title { podcastJson["title"] = title }
        if let author { podcastJson["author"] = author }
        if let description { podcastJson["description"] = description }
        if let descriptionHTML { podcastJson["description_html"] = descriptionHTML }
        if let category { podcastJson["category"] = category }
        if let funding { podcastJson["fundings"] = [["url": funding]] }

        podcastJson["episodes"] = episodes.map { $0.toEpisodeJson() }

        return [
            "podcast": podcastJson,
            "refresh_allowed": true
        ]
    }

    /// Maps every parsed episode to the `RefreshEpisode` shape that
    /// `RefreshOperation` already consumes. `RefreshOperation` dedups by UUID
    /// so we can return the full feed every time without producing duplicates.
    public func refreshEpisodes() -> [RefreshEpisode] {
        episodes.map { $0.toRefreshEpisode() }
    }

    public var imageURLForPodcast: String? { imageURL }
}

extension ParsedEpisode {
    public func toEpisodeJson() -> [String: Any] {
        var json: [String: Any] = [
            "uuid": uuid
        ]
        if let title { json["title"] = title }
        if let downloadURL { json["url"] = downloadURL }
        if let fileType { json["file_type"] = fileType }
        if let sizeInBytes { json["file_size"] = sizeInBytes }
        if let durationSeconds { json["duration"] = durationSeconds }
        if let publishedDate { json["published"] = LocalFeedDateFormatter.iso8601String(from: publishedDate) }
        if let episodeNumber { json["number"] = episodeNumber }
        if let seasonNumber { json["season"] = seasonNumber }
        if let episodeType { json["type"] = episodeType }
        return json
    }

    public func toRefreshEpisode() -> RefreshEpisode {
        var episode = RefreshEpisode()
        episode.uuid = uuid
        episode.title = title
        episode.url = downloadURL
        episode.episodeDescription = description
        episode.detailedDescription = descriptionHTML
        episode.fileType = fileType
        episode.sizeInBytes = sizeInBytes
        episode.duration = durationSeconds
        episode.episodeType = episodeType
        episode.seasonNumber = seasonNumber
        episode.episodeNumber = episodeNumber
        if let publishedDate {
            episode.publishedDate = LocalFeedDateFormatter.refreshDateString(from: publishedDate)
        }
        return episode
    }
}

enum LocalFeedDateFormatter {
    private static let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    /// "yyyy-MM-dd HH:mm:ss" — matches the cache server's published_at format
    /// that `Episode.populate(fromEpisode:)` already parses.
    private static let refreshDate: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f
    }()

    static func iso8601String(from date: Date) -> String { iso8601.string(from: date) }
    static func refreshDateString(from date: Date) -> String { refreshDate.string(from: date) }
}

final class FeedXMLParser: NSObject, XMLParserDelegate {
    private let feedURLString: String

    init(feedURLString: String) {
        self.feedURLString = feedURLString
    }

    private var elementStack: [String] = []
    private var charBuffer = ""

    private var feedTitle: String?
    private var feedAuthor: String?
    private var feedDescription: String?
    private var feedDescriptionHTML: String?
    private var feedImageURL: String?
    private var feedLink: String?
    private var feedCategory: String?
    private var feedLanguage: String?
    private var feedFunding: String?

    private var episodes: [ParsedEpisode] = []
    private var isAtom = false

    private var itemActive = false
    private var itemGuid: String?
    private var itemTitle: String?
    private var itemDownloadURL: String?
    private var itemDescription: String?
    private var itemDescriptionHTML: String?
    private var itemPubDate: String?
    private var itemDuration: String?
    private var itemSize: Int64?
    private var itemFileType: String?
    private var itemEpisodeNumber: Int64?
    private var itemSeasonNumber: Int64?
    private var itemEpisodeType: String?
    private var itemChaptersURL: String?
    private var itemChaptersType: String?
    private var itemTranscriptURL: String?
    private var itemTranscriptType: String?

    func parse(data: Data) -> ParsedFeed? {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.shouldProcessNamespaces = false

        guard parser.parse() else { return nil }

        return ParsedFeed(
            title: feedTitle,
            author: feedAuthor,
            description: feedDescription,
            descriptionHTML: feedDescriptionHTML ?? feedDescription,
            imageURL: feedImageURL,
            link: feedLink,
            category: feedCategory,
            language: feedLanguage,
            funding: feedFunding,
            episodes: episodes
        )
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        let name = qName ?? elementName
        elementStack.append(name)
        charBuffer = ""

        switch name {
        case "feed":
            isAtom = true
        case "item", "entry":
            itemActive = true
            resetItem()
        case "enclosure":
            itemDownloadURL = attributeDict["url"]
            if let len = attributeDict["length"] { itemSize = Int64(len) }
            itemFileType = attributeDict["type"]
        case "itunes:image":
            if !itemActive, feedImageURL == nil {
                feedImageURL = attributeDict["href"]
            }
        case "itunes:category":
            if !itemActive, feedCategory == nil {
                feedCategory = attributeDict["text"]
            }
        case "podcast:chapters":
            if itemActive {
                itemChaptersURL = attributeDict["url"]
                itemChaptersType = attributeDict["type"]
            }
        case "podcast:transcript":
            if itemActive, itemTranscriptURL == nil {
                itemTranscriptURL = attributeDict["url"]
                itemTranscriptType = attributeDict["type"]
            }
        case "podcast:funding":
            if !itemActive, feedFunding == nil {
                feedFunding = attributeDict["url"]
            }
        case "link":
            if isAtom, itemActive, attributeDict["rel"] == "enclosure", let href = attributeDict["href"] {
                itemDownloadURL = href
                if let len = attributeDict["length"] { itemSize = Int64(len) }
                itemFileType = attributeDict["type"]
            } else if isAtom, !itemActive, feedLink == nil, attributeDict["rel"] != "self" {
                feedLink = attributeDict["href"]
            }
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        charBuffer += string
    }

    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        if let s = String(data: CDATABlock, encoding: .utf8) {
            charBuffer += s
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let name = qName ?? elementName
        defer {
            if !elementStack.isEmpty { elementStack.removeLast() }
            charBuffer = ""
        }

        let value = charBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
        let parent = elementStack.dropLast().last

        if itemActive {
            switch name {
            case "title":
                itemTitle = value
            case "guid", "id":
                itemGuid = value
            case "description", "summary":
                if itemDescription == nil { itemDescription = value }
            case "content:encoded", "content":
                itemDescriptionHTML = value
            case "pubDate", "published", "updated":
                if itemPubDate == nil { itemPubDate = value }
            case "itunes:duration":
                itemDuration = value
            case "itunes:season":
                itemSeasonNumber = Int64(value)
            case "itunes:episode":
                itemEpisodeNumber = Int64(value)
            case "itunes:episodeType":
                itemEpisodeType = value
            case "item", "entry":
                commitItem()
                itemActive = false
            default:
                break
            }
        } else {
            switch name {
            case "title":
                if feedTitle == nil { feedTitle = value }
            case "description", "subtitle", "itunes:summary":
                if feedDescription == nil { feedDescription = value }
            case "content:encoded":
                if feedDescriptionHTML == nil { feedDescriptionHTML = value }
            case "itunes:author":
                if feedAuthor == nil { feedAuthor = value }
            case "author":
                if feedAuthor == nil, !isAtom { feedAuthor = value }
            case "name":
                if isAtom, parent == "author", feedAuthor == nil { feedAuthor = value }
            case "link":
                if !isAtom, feedLink == nil { feedLink = value }
            case "language":
                if feedLanguage == nil { feedLanguage = value }
            case "url":
                if parent == "image", feedImageURL == nil { feedImageURL = value }
            default:
                break
            }
        }
    }

    private func resetItem() {
        itemGuid = nil
        itemTitle = nil
        itemDownloadURL = nil
        itemDescription = nil
        itemDescriptionHTML = nil
        itemPubDate = nil
        itemDuration = nil
        itemSize = nil
        itemFileType = nil
        itemEpisodeNumber = nil
        itemSeasonNumber = nil
        itemEpisodeType = nil
        itemChaptersURL = nil
        itemChaptersType = nil
        itemTranscriptURL = nil
        itemTranscriptType = nil
    }

    private func commitItem() {
        guard let identity = itemGuid ?? itemDownloadURL else { return }

        // Feed-scoped identity: GUIDs are only unique within a feed, so the v5
        // name includes the feed URL. The newline separator keeps distinct
        // (feed URL, GUID) pairs from ever concatenating to the same name.
        let uuid = UUID.v5(namespace: .pocketCastsEpisodeNamespace, name: feedURLString + "\n" + identity).uuidString.lowercased()

        episodes.append(ParsedEpisode(
            guid: identity,
            uuid: uuid,
            title: itemTitle,
            downloadURL: itemDownloadURL,
            description: itemDescription,
            descriptionHTML: itemDescriptionHTML ?? itemDescription,
            publishedDate: itemPubDate.flatMap(FeedDateParser.parse),
            durationSeconds: itemDuration.flatMap(FeedDateParser.parseDuration),
            sizeInBytes: itemSize,
            fileType: itemFileType,
            episodeNumber: itemEpisodeNumber,
            seasonNumber: itemSeasonNumber,
            episodeType: itemEpisodeType,
            chaptersURL: itemChaptersURL,
            chaptersType: itemChaptersType,
            transcriptURL: itemTranscriptURL,
            transcriptType: itemTranscriptType
        ))
    }
}

enum FeedDateParser {
    private static let rfc822Formats = [
        "EEE, dd MMM yyyy HH:mm:ss zzz",
        "EEE, dd MMM yyyy HH:mm:ss Z",
        "dd MMM yyyy HH:mm:ss zzz",
        "EEE, dd MMM yyyy HH:mm zzz"
    ]

    static func parse(_ raw: String) -> Date? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let rfc = DateFormatter()
        rfc.locale = Locale(identifier: "en_US_POSIX")
        rfc.timeZone = TimeZone(secondsFromGMT: 0)
        for format in rfc822Formats {
            rfc.dateFormat = format
            if let date = rfc.date(from: trimmed) { return date }
        }

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: trimmed) { return date }
        iso.formatOptions = [.withInternetDateTime]
        if let date = iso.date(from: trimmed) { return date }

        return nil
    }

    static func parseDuration(_ raw: String) -> Double? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let seconds = Double(trimmed) { return seconds }

        let parts = trimmed.split(separator: ":").map { Double($0) ?? 0 }
        switch parts.count {
        case 3: return parts[0] * 3600 + parts[1] * 60 + parts[2]
        case 2: return parts[0] * 60 + parts[1]
        default: return nil
        }
    }
}
