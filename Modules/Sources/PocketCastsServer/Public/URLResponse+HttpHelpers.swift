import Foundation

extension URLResponse {
    var etag: String? {
        (self as? HTTPURLResponse)?.allHeaderFields[ServerConstants.HttpHeaders.etag] as? String
    }

    var lastModified: String? {
        (self as? HTTPURLResponse)?.allHeaderFields[ServerConstants.HttpHeaders.lastModified] as? String
    }

    public func extractStatusCode() -> Int {
        if let httpResponse = self as? HTTPURLResponse {
            return httpResponse.statusCode
        }

        return 0
    }
}
