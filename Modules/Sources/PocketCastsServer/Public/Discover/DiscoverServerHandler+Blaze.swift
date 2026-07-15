import Foundation
import PocketCastsUtils

public struct BlazePromotion: Decodable {
    public let id: String
    public let text: String
    public let imageURL: URL
    public let urlTitle: String
    public let url: URL
    public let urlAndroid: URL
    public let urlApple: URL
    public let location: Location

    public enum Location: String, Decodable {
        case podcastList = "podcast_list"
        case player
        case unknown

        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let rawValue = try container.decode(String.self)
            self = Location(rawValue: rawValue) ?? .unknown
        }
    }
}

extension DiscoverServerHandler {
    /// Blaze promotions were served by the Pocket Casts server (`blaze/promotions.json`).
    /// With the server gone there are no promotions to fetch, so this never calls
    /// completion and no banner ad is ever shown.
    public func blazePromotion(for location: BlazePromotion.Location, completion: @escaping (BlazePromotion, Bool) -> Void) {}
}
