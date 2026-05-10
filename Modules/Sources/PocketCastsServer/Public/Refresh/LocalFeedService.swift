import Foundation
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
    /// Stable UUID v5 derived from the feed's GUID, suitable for the existing
    /// Podcast Casts data model where episodes are keyed by UUID.
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

        let parser = FeedXMLParser()
        guard let feed = parser.parse(data: data) else { throw LocalFeedFetchError.parseFailed }

        return .success(
            feed: feed,
            lastModified: http?.value(forHTTPHeaderField: ServerConstants.HttpHeaders.lastModified),
            etag: http?.value(forHTTPHeaderField: ServerConstants.HttpHeaders.etag)
        )
    }
}

final class FeedXMLParser: NSObject, XMLParserDelegate {
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

        let uuid = UUID.v5(namespace: .pocketCastsEpisodeNamespace, name: identity).uuidString.lowercased()

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
