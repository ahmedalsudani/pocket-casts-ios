import Foundation

/// A generic request handler to send URLRequests with a completion block
public protocol RequestHandler {
    func send(request: URLRequest, completion: @escaping (Data?, URLResponse?, Error?) -> Void)
}

extension URLSession: RequestHandler {
    public func send(request: URLRequest, completion: @escaping (Data?, URLResponse?, Error?) -> Void) {
        let task = dataTask(with: request, completionHandler: completion)
        task.resume()
    }
}

public class URLConnection {

    private let handler: RequestHandler

    public init(handler: RequestHandler) {
        self.handler = handler
    }

    public func send(request: URLRequest, completion: @escaping (Data?, URLResponse?, Error?) -> Void) {
        handler.send(request: request, completion: completion)
    }

    public func send(request: URLRequest) async throws -> (Data?, URLResponse?) {
        try await withCheckedThrowingContinuation { continuation in
            send(request: request) { data, response, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: (data, response))
                }
            }
        }
    }
}
