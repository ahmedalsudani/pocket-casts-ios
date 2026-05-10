import Foundation
import PocketCastsDataModel
@testable import PocketCastsServer
import XCTest

final class LocalFeedServiceRefreshTests: XCTestCase {
    func testRefreshFansOutAcrossPodcasts() async throws {
        let body = fixtureData(name: "feed-rss2", ext: "xml")
        let connection = URLConnection(mockHandler: { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)
            return (body, response)
        })
        let service = LocalFeedService(connection: connection)

        let podcastA = makePodcast(uuid: "uuid-a", feedURL: "https://a.example.com/feed.xml")
        let podcastB = makePodcast(uuid: "uuid-b", feedURL: "https://b.example.com/feed.xml")

        let response = await service.refresh(podcasts: [podcastA, podcastB])

        XCTAssertTrue(response.success())
        XCTAssertEqual(response.result?.podcastUpdates?["uuid-a"]?.count, 2)
        XCTAssertEqual(response.result?.podcastUpdates?["uuid-b"]?.count, 2)

        let firstA = response.result?.podcastUpdates?["uuid-a"]?.first
        XCTAssertEqual(firstA?.title, "Episode One")
        XCTAssertEqual(firstA?.url, "https://example.com/episodes/one.mp3")
        XCTAssertEqual(firstA?.duration, 5025)
        XCTAssertEqual(firstA?.publishedDate, "2025-05-05 12:00:00")
    }

    func testRefreshSkipsPodcastsWithoutFeedURL() async {
        let body = fixtureData(name: "feed-rss2", ext: "xml")
        let connection = URLConnection(mockHandler: { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)
            return (body, response)
        })
        let service = LocalFeedService(connection: connection)

        let podcastWithURL = makePodcast(uuid: "has-url", feedURL: "https://example.com/feed.xml")
        let podcastWithoutURL = makePodcast(uuid: "no-url", feedURL: nil)

        let response = await service.refresh(podcasts: [podcastWithURL, podcastWithoutURL])

        XCTAssertNotNil(response.result?.podcastUpdates?["has-url"])
        XCTAssertNil(response.result?.podcastUpdates?["no-url"])
    }

    func testRefreshSkipsFailedFeeds() async {
        var requestCount = 0
        let body = fixtureData(name: "feed-rss2", ext: "xml")
        let connection = URLConnection(mockHandler: { request in
            requestCount += 1
            if request.url?.host == "fail.example.com" {
                let response = HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)
                return (Data(), response)
            }
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)
            return (body, response)
        })
        let service = LocalFeedService(connection: connection)

        let podcastOK = makePodcast(uuid: "ok", feedURL: "https://example.com/feed.xml")
        let podcastFail = makePodcast(uuid: "fail", feedURL: "https://fail.example.com/feed.xml")

        let response = await service.refresh(podcasts: [podcastOK, podcastFail])

        XCTAssertEqual(requestCount, 2)
        XCTAssertNotNil(response.result?.podcastUpdates?["ok"])
        XCTAssertNil(response.result?.podcastUpdates?["fail"])
    }

    func testITunesLookupReturnsFeedURL() async throws {
        let lookupBody = """
        {"resultCount": 1, "results": [{"feedUrl": "https://example.com/feed.xml", "collectionName": "Sample Podcast"}]}
        """.data(using: .utf8)!
        let connection = URLConnection(mockHandler: { request in
            XCTAssertEqual(request.url?.host, "itunes.apple.com")
            XCTAssertEqual(request.url?.query, "id=1234&entity=podcast")
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)
            return (lookupBody, response)
        })
        let service = LocalFeedService(connection: connection)

        let url = try await service.iTunesLookup(iTunesId: 1234)

        XCTAssertEqual(url?.absoluteString, "https://example.com/feed.xml")
    }

    func testITunesLookupReturnsNilWhenEmpty() async throws {
        let lookupBody = #"{"resultCount": 0, "results": []}"#.data(using: .utf8)!
        let connection = URLConnection(mockHandler: { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)
            return (lookupBody, response)
        })
        let service = LocalFeedService(connection: connection)

        let url = try await service.iTunesLookup(iTunesId: 9999)

        XCTAssertNil(url)
    }

    func testParsedFeedToPodcastInfoJson() throws {
        let connection = URLConnection(mockHandler: { request in
            let body = self.fixtureData(name: "feed-rss2", ext: "xml")
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)
            return (body, response)
        })
        let service = LocalFeedService(connection: connection)

        let expectation = self.expectation(description: "fetch")
        var capturedFeed: ParsedFeed?
        Task {
            let result = try await service.fetch(feedURL: URL(string: "https://example.com/feed.xml")!)
            if case .success(let feed, _, _) = result { capturedFeed = feed }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)

        let feed = try XCTUnwrap(capturedFeed)
        let info = feed.toPodcastInfoJson(uuid: "abc-uuid", feedURLString: "https://example.com/feed.xml")

        let podcastDict = try XCTUnwrap(info["podcast"] as? [String: Any])
        XCTAssertEqual(podcastDict["uuid"] as? String, "abc-uuid")
        XCTAssertEqual(podcastDict["url"] as? String, "https://example.com/feed.xml")
        XCTAssertEqual(podcastDict["title"] as? String, "Sample Podcast")
        XCTAssertEqual(podcastDict["author"] as? String, "Jane Doe")
        XCTAssertEqual(podcastDict["category"] as? String, "Technology")
        XCTAssertEqual(info["refresh_allowed"] as? Bool, true)

        let episodes = try XCTUnwrap(podcastDict["episodes"] as? [[String: Any]])
        XCTAssertEqual(episodes.count, 2)
        XCTAssertEqual(episodes[0]["title"] as? String, "Episode One")
        XCTAssertEqual(episodes[0]["url"] as? String, "https://example.com/episodes/one.mp3")
        XCTAssertEqual(episodes[0]["duration"] as? Double, 5025)
        XCTAssertEqual(episodes[0]["file_size"] as? Int64, 12345678)
        XCTAssertEqual(episodes[0]["type"] as? String, "full")
        XCTAssertNotNil(episodes[0]["published"] as? String)
    }

    // MARK: - Helpers

    private func fixtureData(name: String, ext: String) -> Data {
        let bundle = Bundle.module
        guard let url = bundle.url(forResource: name, withExtension: ext, subdirectory: "Fixtures") else {
            fatalError("Missing fixture \(name).\(ext)")
        }
        return (try? Data(contentsOf: url)) ?? Data()
    }

    private func makePodcast(uuid: String, feedURL: String?) -> Podcast {
        let podcast = Podcast()
        podcast.uuid = uuid
        podcast.podcastUrl = feedURL
        return podcast
    }
}
