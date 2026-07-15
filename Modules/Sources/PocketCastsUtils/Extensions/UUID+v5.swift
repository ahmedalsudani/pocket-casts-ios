import CryptoKit
import Foundation

extension UUID {
    /// Stable namespace for podcast UUIDs derived from RSS feed URLs.
    /// Once shipped, this value must never change — it's the namespace input
    /// for every UUIDv5 we generate from a feed URL.
    public static let pocketCastsPodcastNamespace = UUID(uuidString: "8a6e9e0a-3b49-4b9d-9e6c-9f2b7a3d4c5e")!

    /// Stable namespace for episode UUIDs derived from feed item GUIDs.
    public static let pocketCastsEpisodeNamespace = UUID(uuidString: "5f4d1c2b-8e3a-4f1d-9c0a-7b2e6d5a8c4f")!

    /// RFC 4122 v5 UUID derived from a namespace and a name using SHA-1.
    public static func v5(namespace: UUID, name: String) -> UUID {
        let namespaceBytes = withUnsafeBytes(of: namespace.uuid) { Array($0) }

        var hasher = Insecure.SHA1()
        hasher.update(data: Data(namespaceBytes))
        hasher.update(data: Data(name.utf8))
        var bytes = Array(hasher.finalize().prefix(16))

        bytes[6] = (bytes[6] & 0x0F) | 0x50
        bytes[8] = (bytes[8] & 0x3F) | 0x80

        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }
}
