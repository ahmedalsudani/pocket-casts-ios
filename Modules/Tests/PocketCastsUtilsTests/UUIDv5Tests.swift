import Foundation
import PocketCastsUtils
import XCTest

final class UUIDv5Tests: XCTestCase {
    func test_isDeterministic() {
        let a = UUID.v5(namespace: .pocketCastsPodcastNamespace, name: "https://example.com/feed.xml")
        let b = UUID.v5(namespace: .pocketCastsPodcastNamespace, name: "https://example.com/feed.xml")
        XCTAssertEqual(a, b)
    }

    func test_differentNamesProduceDifferentUUIDs() {
        let a = UUID.v5(namespace: .pocketCastsPodcastNamespace, name: "https://a.example.com/feed.xml")
        let b = UUID.v5(namespace: .pocketCastsPodcastNamespace, name: "https://b.example.com/feed.xml")
        XCTAssertNotEqual(a, b)
    }

    func test_differentNamespacesProduceDifferentUUIDs() {
        let a = UUID.v5(namespace: .pocketCastsPodcastNamespace, name: "x")
        let b = UUID.v5(namespace: .pocketCastsEpisodeNamespace, name: "x")
        XCTAssertNotEqual(a, b)
    }

    func test_isVersion5() {
        let uuid = UUID.v5(namespace: .pocketCastsPodcastNamespace, name: "anything")
        let bytes = withUnsafeBytes(of: uuid.uuid) { Array($0) }
        XCTAssertEqual(bytes[6] >> 4, 0x5, "Version nibble should be 5")
        XCTAssertEqual(bytes[8] >> 6, 0x2, "Variant bits should be 10 (RFC 4122)")
    }

    /// Reference vector: SHA1("dns" namespace + "www.example.com") truncated and
    /// version/variant tagged. Verified against multiple independent UUIDv5
    /// implementations.
    func test_referenceVector_DNS_www_example_com() {
        let dnsNamespace = UUID(uuidString: "6ba7b810-9dad-11d1-80b4-00c04fd430c8")!
        let uuid = UUID.v5(namespace: dnsNamespace, name: "www.example.com")
        XCTAssertEqual(uuid.uuidString.lowercased(), "2ed6657d-e927-568b-95e1-2665a8aea6a2")
    }
}
