import Foundation
@testable import PocketCastsServer
import PocketCastsUtils
import XCTest

final class LocalFeedServiceTests: XCTestCase {
    func testParsesRSS2FeedWithITunesNamespace() async throws {
        let service = LocalFeedService(connection: makeConnection(fixture: "feed-rss2", ext: "xml"))

        let result = try await service.fetch(feedURL: URL(string: "https://example.com/feed.xml")!)

        guard case .success(let feed, _, _) = result else {
            return XCTFail("Expected success, got \(result)")
        }

        XCTAssertEqual(feed.title, "Sample Podcast")
        XCTAssertEqual(feed.author, "Jane Doe")
        XCTAssertEqual(feed.imageURL, "https://example.com/cover.jpg")
        XCTAssertEqual(feed.link, "https://example.com/podcast")
        XCTAssertEqual(feed.language, "en-us")
        XCTAssertEqual(feed.category, "Technology")
        XCTAssertEqual(feed.episodes.count, 2)

        let first = feed.episodes[0]
        XCTAssertEqual(first.guid, "episode-one-guid")
        XCTAssertEqual(first.title, "Episode One")
        XCTAssertEqual(first.downloadURL, "https://example.com/episodes/one.mp3")
        XCTAssertEqual(first.sizeInBytes, 12345678)
        XCTAssertEqual(first.fileType, "audio/mpeg")
        XCTAssertEqual(first.durationSeconds, 5025)
        XCTAssertEqual(first.episodeNumber, 1)
        XCTAssertEqual(first.seasonNumber, 1)
        XCTAssertEqual(first.episodeType, "full")
        XCTAssertEqual(first.descriptionHTML, "<p>The first episode <strong>HTML</strong> body.</p>")
        XCTAssertNotNil(first.publishedDate)

        let second = feed.episodes[1]
        XCTAssertEqual(second.guid, "episode-two-guid")
        XCTAssertEqual(second.durationSeconds, 2400)
    }

    func testParsesAtomFeed() async throws {
        let service = LocalFeedService(connection: makeConnection(fixture: "feed-atom", ext: "xml"))

        let result = try await service.fetch(feedURL: URL(string: "https://example.com/atom")!)

        guard case .success(let feed, _, _) = result else {
            return XCTFail("Expected success, got \(result)")
        }

        XCTAssertEqual(feed.title, "Atom Sample Podcast")
        XCTAssertEqual(feed.author, "Atom Author")
        XCTAssertEqual(feed.link, "https://example.com/atom")
        XCTAssertEqual(feed.episodes.count, 2)

        let first = feed.episodes[0]
        XCTAssertEqual(first.guid, "tag:example.com,2025:atom-episode-one")
        XCTAssertEqual(first.title, "Atom Episode One")
        XCTAssertEqual(first.downloadURL, "https://example.com/atom/episodes/one.mp3")
        XCTAssertEqual(first.sizeInBytes, 2222222)
        XCTAssertEqual(first.fileType, "audio/mpeg")
        XCTAssertNotNil(first.publishedDate)
    }

    func testParsesPodcasting2NamespaceFields() async throws {
        let service = LocalFeedService(connection: makeConnection(fixture: "feed-podcasting2", ext: "xml"))

        let result = try await service.fetch(feedURL: URL(string: "https://example.com/p2/feed.xml")!)

        guard case .success(let feed, _, _) = result else {
            return XCTFail("Expected success, got \(result)")
        }

        XCTAssertEqual(feed.funding, "https://example.com/p2/donate")
        XCTAssertEqual(feed.episodes.count, 1)

        let only = feed.episodes[0]
        XCTAssertEqual(only.transcriptURL, "https://example.com/p2/episodes/one.vtt")
        XCTAssertEqual(only.transcriptType, "text/vtt")
        XCTAssertEqual(only.chaptersURL, "https://example.com/p2/episodes/one.chapters.json")
        XCTAssertEqual(only.chaptersType, "application/json+chapters")
        XCTAssertEqual(only.durationSeconds, 1800)
    }

    func testEpisodesGetStableUUIDsAcrossFetches() async throws {
        let service1 = LocalFeedService(connection: makeConnection(fixture: "feed-rss2", ext: "xml"))
        let service2 = LocalFeedService(connection: makeConnection(fixture: "feed-rss2", ext: "xml"))

        let r1 = try await service1.fetch(feedURL: URL(string: "https://example.com/feed.xml")!)
        let r2 = try await service2.fetch(feedURL: URL(string: "https://example.com/feed.xml")!)

        guard case .success(let f1, _, _) = r1, case .success(let f2, _, _) = r2 else {
            return XCTFail("Expected success on both fetches")
        }

        XCTAssertEqual(f1.episodes.map(\.uuid), f2.episodes.map(\.uuid))
        XCTAssertNotEqual(f1.episodes[0].uuid, f1.episodes[1].uuid)
    }

    func testEpisodeUUIDsDifferAcrossFeedsWithSameGuids() async throws {
        // Two different feeds serving items with identical GUIDs must not
        // produce colliding episode UUIDs — identity is scoped to the feed URL.
        let service1 = LocalFeedService(connection: makeConnection(fixture: "feed-rss2", ext: "xml"))
        let service2 = LocalFeedService(connection: makeConnection(fixture: "feed-rss2", ext: "xml"))

        let r1 = try await service1.fetch(feedURL: URL(string: "https://a.example.com/feed.xml")!)
        let r2 = try await service2.fetch(feedURL: URL(string: "https://b.example.com/feed.xml")!)

        guard case .success(let f1, _, _) = r1, case .success(let f2, _, _) = r2 else {
            return XCTFail("Expected success on both fetches")
        }

        let uuids1 = Set(f1.episodes.map(\.uuid))
        let uuids2 = Set(f2.episodes.map(\.uuid))
        XCTAssertEqual(uuids1.count, f1.episodes.count)
        XCTAssertEqual(uuids2.count, f2.episodes.count)
        XCTAssertTrue(uuids1.isDisjoint(with: uuids2))
    }

    func testEpisodeUUIDIsDeterministicV5() async throws {
        // Pins the identity derivation formula: v5(episodeNamespace, feedURL + "\n" + guid).
        // If this test ever fails, the change would re-key every episode in
        // existing libraries — don't change the formula.
        let service = LocalFeedService(connection: makeConnection(fixture: "feed-rss2", ext: "xml"))

        let result = try await service.fetch(feedURL: URL(string: "https://example.com/feed.xml")!)
        guard case .success(let feed, _, _) = result else {
            return XCTFail("Expected success, got \(result)")
        }

        let expected = UUID.v5(
            namespace: .pocketCastsEpisodeNamespace,
            name: "https://example.com/feed.xml\nepisode-one-guid"
        ).uuidString.lowercased()
        XCTAssertEqual(feed.episodes[0].uuid, expected)
    }

    func testNotModifiedShortCircuits() async throws {
        let url = URL(string: "https://example.com/feed.xml")!
        let connection = URLConnection(mockHandler: { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 304, httpVersion: nil, headerFields: nil)
            return (nil, response)
        })

        let service = LocalFeedService(connection: connection)
        let result = try await service.fetch(feedURL: url, lastModified: "Mon, 05 May 2025 12:00:00 GMT")

        guard case .notModified = result else {
            return XCTFail("Expected .notModified, got \(result)")
        }
    }

    func testHTTPErrorThrows() async {
        let connection = URLConnection(mockHandler: { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)
            return (Data(), response)
        })

        let service = LocalFeedService(connection: connection)

        do {
            _ = try await service.fetch(feedURL: URL(string: "https://example.com/feed.xml")!)
            XCTFail("Expected throw")
        } catch let LocalFeedFetchError.httpError(status) {
            XCTAssertEqual(status, 500)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testCapturesLastModifiedAndETag() async throws {
        let body = fixtureData(name: "feed-rss2", ext: "xml")
        let connection = URLConnection(mockHandler: { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: [
                    "Last-Modified": "Mon, 12 May 2025 13:00:00 GMT",
                    "ETag": "\"abc123\""
                ]
            )
            return (body, response)
        })

        let service = LocalFeedService(connection: connection)
        let result = try await service.fetch(feedURL: URL(string: "https://example.com/feed.xml")!)

        guard case .success(_, let lastModified, let etag) = result else {
            return XCTFail("Expected success, got \(result)")
        }

        XCTAssertEqual(lastModified, "Mon, 12 May 2025 13:00:00 GMT")
        XCTAssertEqual(etag, "\"abc123\"")
    }

    func testRequestSendsConditionalHeaders() async throws {
        let body = fixtureData(name: "feed-rss2", ext: "xml")
        var capturedRequest: URLRequest?

        let connection = URLConnection(mockHandler: { request in
            capturedRequest = request
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)
            return (body, response)
        })

        let service = LocalFeedService(connection: connection)
        _ = try await service.fetch(
            feedURL: URL(string: "https://example.com/feed.xml")!,
            lastModified: "Mon, 05 May 2025 12:00:00 GMT",
            etag: "\"prev\""
        )

        XCTAssertEqual(capturedRequest?.value(forHTTPHeaderField: "If-Modified-Since"), "Mon, 05 May 2025 12:00:00 GMT")
        XCTAssertEqual(capturedRequest?.value(forHTTPHeaderField: "If-None-Match"), "\"prev\"")
    }

    // MARK: - Helpers

    private func fixtureData(name: String, ext: String) -> Data {
        let bundle = Bundle.module
        guard let url = bundle.url(forResource: name, withExtension: ext, subdirectory: "Fixtures") else {
            fatalError("Missing fixture \(name).\(ext)")
        }
        return (try? Data(contentsOf: url)) ?? Data()
    }

    private func makeConnection(fixture: String, ext: String) -> URLConnection {
        let body = fixtureData(name: fixture, ext: ext)
        return URLConnection(mockHandler: { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)
            return (body, response)
        })
    }
}
