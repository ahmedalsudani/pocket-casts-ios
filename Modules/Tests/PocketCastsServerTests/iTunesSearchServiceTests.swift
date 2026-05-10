import Foundation
@testable import PocketCastsServer
import XCTest

final class iTunesSearchServiceTests: XCTestCase {
    func testParsesITunesSearchResults() async throws {
        let body = """
        {
          "resultCount": 2,
          "results": [
            {
              "collectionId": 111,
              "collectionName": "Sample Podcast One",
              "artistName": "Author One",
              "feedUrl": "https://one.example.com/feed.xml"
            },
            {
              "trackId": 222,
              "trackName": "Sample Podcast Two",
              "artistName": "Author Two",
              "feedUrl": "https://two.example.com/feed.xml"
            }
          ]
        }
        """.data(using: .utf8)!

        let connection = URLConnection(mockHandler: { request in
            XCTAssertEqual(request.url?.host, "itunes.apple.com")
            XCTAssertEqual(request.url?.path, "/search")
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)
            return (body, response)
        })
        let service = iTunesSearchService(connection: connection)

        let results = try await service.search(term: "sample")

        XCTAssertEqual(results.count, 2)

        XCTAssertEqual(results[0].title, "Sample Podcast One")
        XCTAssertEqual(results[0].author, "Author One")
        XCTAssertEqual(results[0].iTunesId, 111)
        XCTAssertEqual(results[0].kind, .podcast)
        XCTAssertEqual(results[0].isLocal, false)

        XCTAssertEqual(results[1].title, "Sample Podcast Two")
        XCTAssertEqual(results[1].iTunesId, 222)
    }

    func testEmptyTermReturnsEmpty() async throws {
        var requestSent = false
        let connection = URLConnection(mockHandler: { _ in
            requestSent = true
            return (Data(), nil)
        })
        let service = iTunesSearchService(connection: connection)

        let results = try await service.search(term: "   ")

        XCTAssertEqual(results.count, 0)
        XCTAssertFalse(requestSent)
    }

    func testSkipsResultsMissingFeedURL() async throws {
        let body = """
        {
          "resultCount": 2,
          "results": [
            {"collectionId": 111, "collectionName": "Has Feed", "feedUrl": "https://example.com/feed.xml"},
            {"collectionId": 222, "collectionName": "No Feed"}
          ]
        }
        """.data(using: .utf8)!
        let connection = URLConnection(mockHandler: { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)
            return (body, response)
        })
        let service = iTunesSearchService(connection: connection)

        let results = try await service.search(term: "sample")

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].title, "Has Feed")
    }

    func testDerivesUUIDFromFeedURL() async throws {
        let body = """
        {"resultCount": 1, "results": [{"collectionId": 1, "collectionName": "X", "feedUrl": "https://example.com/feed.xml"}]}
        """.data(using: .utf8)!
        let connection = URLConnection(mockHandler: { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)
            return (body, response)
        })
        let service = iTunesSearchService(connection: connection)

        let results1 = try await service.search(term: "x")
        let results2 = try await service.search(term: "x")

        XCTAssertEqual(results1.first?.uuid, results2.first?.uuid)
    }

    func testPodcastInfoFromiTunesResultPrefersITunesId() {
        let result = PodcastFolderSearchResult(
            uuid: "uuid-derived",
            title: "Title",
            author: "Author",
            kind: .podcast,
            isLocal: false,
            iTunesId: 1234
        )

        let info = PodcastInfo(from: result)

        XCTAssertEqual(info.iTunesId, 1234)
        XCTAssertNil(info.uuid, "Server-resolved UUID lookups are gone; iTunesId routing should win")
    }

    func testPodcastInfoFromNonITunesResultUsesUuid() {
        let result = PodcastFolderSearchResult(
            uuid: "real-uuid",
            title: "Title",
            author: "Author",
            kind: .podcast,
            isLocal: false,
            iTunesId: nil
        )

        let info = PodcastInfo(from: result)

        XCTAssertEqual(info.uuid, "real-uuid")
        XCTAssertNil(info.iTunesId)
    }
}
