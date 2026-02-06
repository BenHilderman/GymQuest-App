import Foundation

/// Stubbed response data for MockURLProtocol
struct StubbedResponse {
    let data: Data
    let statusCode: Int
    let headers: [String: String]

    init(data: Data, statusCode: Int = 200, headers: [String: String] = ["Content-Type": "application/json"]) {
        self.data = data
        self.statusCode = statusCode
        self.headers = headers
    }
}

/// URLProtocol subclass that intercepts URLSession.shared requests for offline testing.
/// Uses substring matching on the request URL to find matching stubs.
final class MockURLProtocol: URLProtocol {

    /// Map of URL substrings to stubbed responses.
    /// Example: ["api.openai.com": StubbedResponse(data: fixtureData)]
    static var stubbedResponses: [String: StubbedResponse] = [:]

    /// Optional handler for inspecting intercepted requests
    static var requestHandler: ((URLRequest) -> Void)?

    override class func canInit(with request: URLRequest) -> Bool {
        // Intercept all HTTP/HTTPS requests
        return true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    override func startLoading() {
        let urlString = request.url?.absoluteString ?? ""

        // Notify handler if set (for request inspection in tests)
        MockURLProtocol.requestHandler?(request)

        // Find a matching stub by substring
        if let match = MockURLProtocol.stubbedResponses.first(where: { urlString.contains($0.key) }) {
            let stub = match.value
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: stub.statusCode,
                httpVersion: "HTTP/1.1",
                headerFields: stub.headers
            )!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: stub.data)
            client?.urlProtocolDidFinishLoading(self)
        } else {
            // No stub found — return a 404
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 404,
                httpVersion: "HTTP/1.1",
                headerFields: nil
            )!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Data())
            client?.urlProtocolDidFinishLoading(self)
        }
    }

    override func stopLoading() {
        // No-op — all responses are delivered synchronously in startLoading
    }
}
